# The DEMO HOST: a persistent VM on dragon playing beefcake-host's role in
# the Model B design — owns the ZFS pool, runs virtio state plumbing, and
# manages the blue/green slot lifecycle. Nested KVM runs the slots inside.
#
# Slot runners are baked into this closure; the store is shared read-only
# from dragon by the VM runner, so slot closures need no copying — exactly
# the "guest closures live in the host store" property from DD2/DD3.
{
  slotVMs, # { blue = <run-slot-blue-vm pkg>; green = <...>; }
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Fixed port map (inside the demo host):
  #   12201/12202 = blue/green ssh, 13001/13002 = blue/green http,
  #   8000 = the "service VIP" (socat, repointed at cutover)
  ports = {
    blue = {
      ssh = 12201;
      http = 13001;
    };
    green = {
      ssh = 12202;
      http = 13002;
    };
  };

  slotRun = pkgs.writeShellApplication {
    name = "slot-run";
    runtimeInputs = with pkgs; [
      zfs
      systemd
      coreutils
      openssh
    ];
    text = ''
      slot=$1; mode=''${2:-real}
      case $slot in
        blue)  sshp=${toString ports.blue.ssh};  httpp=${toString ports.blue.http};  runner=${slotVMs.blue}/bin/run-slot-blue-vm ;;
        green) sshp=${toString ports.green.ssh}; httpp=${toString ports.green.http}; runner=${slotVMs.green}/bin/run-slot-green-vm ;;
        *) echo "usage: slot-run <blue|green> [validate]"; exit 1 ;;
      esac

      share=/demo/shared
      zvol=/dev/zvol/demo/zvols/pg
      restrict=""

      slot_ssh() { # slot_ssh <port> <cmd...>
        p=$1; shift
        ssh -i /etc/demo-ssh-key -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o BatchMode=yes \
          -p "$p" root@localhost "$@"
      }

      if [ "$mode" = validate ]; then
        # QUIESCE the active slot before snapshotting: sqlite WAL under
        # synchronous=NORMAL lives in the guest page cache, so a live
        # host-side snapshot would miss recent commits (found the hard way:
        # a vaultwarden account registered minutes earlier was absent from
        # the clone). `sync` flushes guest caches through 9p to the host.
        for other in blue green; do
          if systemctl is-active -q "slot-$other.service" \
             && [ "$(cat "/var/lib/demo/mode-$other" 2>/dev/null)" = real ]; then
            op=$([ "$other" = blue ] && echo 12201 || echo 12202)
            slot_ssh "$op" sync || echo "WARN: quiesce of $other failed"
          fi
        done
        zfs destroy -r demo/shared-validate 2>/dev/null || true
        zfs destroy -r demo/zvols/pg-validate 2>/dev/null || true
        zfs destroy demo/shared@validate 2>/dev/null || true
        zfs destroy demo/zvols/pg@validate 2>/dev/null || true
        zfs snapshot demo/shared@validate
        zfs snapshot demo/zvols/pg@validate
        zfs clone -o mountpoint=/demo/shared-validate demo/shared@validate demo/shared-validate
        zfs clone demo/zvols/pg@validate demo/zvols/pg-validate
        udevadm settle
        share=/demo/shared-validate
        zvol=/dev/zvol/demo/zvols/pg-validate
        restrict=",restrict=on"
      else
        for other in blue green; do
          [ "$other" = "$slot" ] && continue
          if systemctl is-active -q "slot-$other.service" \
             && [ "$(cat "/var/lib/demo/mode-$other" 2>/dev/null)" = real ]; then
            echo "REFUSING: slot-$other already holds the real state"; exit 1
          fi
        done
      fi

      mkdir -p /var/lib/demo
      echo "$mode" > "/var/lib/demo/mode-$slot"

      systemd-run --unit="slot-$slot" --collect \
        -p WorkingDirectory=/var/lib/demo \
        -E QEMU_OPTS="-virtfs local,path=$share,security_model=none,mount_tag=state -drive format=raw,file=$zvol,if=virtio,werror=report" \
        -E QEMU_NET_OPTS="hostfwd=tcp:0.0.0.0:$sshp-:22,hostfwd=tcp:0.0.0.0:$httpp-:8000$restrict" \
        "$runner"
      echo "slot $slot starting ($mode): ssh :$sshp http :$httpp"
    '';
  };

  slotStop = pkgs.writeShellApplication {
    name = "slot-stop";
    runtimeInputs = with pkgs; [
      zfs
      systemd
      openssh
    ];
    text = ''
      slot=$1
      # Clean guest shutdown first: SIGTERM-ing qemu drops guest page cache
      # (unfsynced sqlite WAL commits die with it). ssh poweroff -> systemd
      # stops services -> filesystems flush; fall back to unit stop.
      p=$([ "$slot" = blue ] && echo 12201 || echo 12202)
      if systemctl is-active -q "slot-$slot.service"; then
        ssh -i /etc/demo-ssh-key -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o BatchMode=yes \
          -p "$p" root@localhost poweroff 2>/dev/null || true
        for _ in $(seq 30); do
          systemctl is-active -q "slot-$slot.service" || break
          sleep 2
        done
      fi
      systemctl stop "slot-$slot.service" 2>/dev/null || true
      if [ "$(cat "/var/lib/demo/mode-$slot" 2>/dev/null)" = validate ]; then
        # validation teardown: discard clones, real state untouched
        zfs destroy -r demo/shared-validate 2>/dev/null || true
        zfs destroy -r demo/zvols/pg-validate 2>/dev/null || true
        zfs destroy demo/shared@validate 2>/dev/null || true
        zfs destroy demo/zvols/pg@validate 2>/dev/null || true
        echo "validation clones discarded; origin state untouched"
      fi
      rm -f "/var/lib/demo/mode-$slot"
      echo "slot $slot stopped"
    '';
  };

  vipSet = pkgs.writeShellApplication {
    name = "vip-set";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      slot=$1
      case $slot in
        blue)  port=${toString ports.blue.http} ;;
        green) port=${toString ports.green.http} ;;
        *) echo "usage: vip-set <blue|green>"; exit 1 ;;
      esac
      mkdir -p /var/lib/demo
      echo "VIP_TARGET_PORT=$port" > /var/lib/demo/vip.env
      echo "$slot" > /var/lib/demo/active
      systemctl restart demo-vip.service
      echo "service VIP :8000 -> $slot (:$port)"
    '';
  };

  cutover = pkgs.writeShellApplication {
    name = "cutover";
    runtimeInputs = with pkgs; [
      systemd
      curl
      coreutils
      zfs
    ];
    text = ''
      target=$1
      active=$(cat /var/lib/demo/active 2>/dev/null || echo none)
      if [ "$target" = "$active" ]; then echo "$target is already active"; exit 1; fi

      echo "== pre-cutover snapshot (rollback bound) =="
      zfs snapshot -r "demo@pre-cutover-$(cat /proc/sys/kernel/random/uuid | cut -c1-8)"

      if systemctl is-active -q "slot-$target.service"; then
        echo "== stopping $target's validation instance =="
        slot-stop "$target"
      fi

      echo "== stopping active slot ($active) =="
      [ "$active" != none ] && slot-stop "$active"

      echo "== starting $target with the REAL state =="
      slot-run "$target" real

      echo "== waiting for $target's web service =="
      port=$([ "$target" = blue ] && echo ${toString ports.blue.http} || echo ${toString ports.green.http})
      for _ in $(seq 60); do
        if curl -fsS -o /dev/null "http://127.0.0.1:$port/alive" 2>/dev/null; then break; fi
        sleep 2
      done

      vip-set "$target"
      echo "== CUTOVER COMPLETE: $target is live =="
      echo "   (rollback: cutover $active)"
    '';
  };

  demoStatus = pkgs.writeShellApplication {
    name = "demo-status";
    runtimeInputs = with pkgs; [
      zfs
      systemd
      curl
      coreutils
    ];
    text = ''
      echo "== active slot: $(cat /var/lib/demo/active 2>/dev/null || echo none) =="
      for s in blue green; do
        state=$(systemctl is-active "slot-$s.service" 2>/dev/null || true)
        mode=$(cat "/var/lib/demo/mode-$s" 2>/dev/null || true)
        echo "slot-$s: $state ''${mode:+($mode)}"
      done
      echo; zfs list -t all -o name,used,mountpoint -r demo 2>/dev/null || echo "(pool not initialized)"
      echo; echo "VIP :8000 -> $(cat /var/lib/demo/vip.env 2>/dev/null || echo unset)"
    '';
  };
in
{
  system.stateVersion = "24.05";
  networking.hostName = "demo-host";
  networking.hostId = "541ede55";

  virtualisation = {
    memorySize = 8192;
    cores = 8;
    # Persistent root disk (default ./demo-host.qcow2 in the launch dir):
    # the pool vdev + /var/lib/demo live here across restarts.
    diskSize = 20 * 1024;
    graphics = false;
    qemu.options = [ "-cpu host" ]; # nested KVM for the slots
  };

  boot.supportedFilesystems = [ "zfs" ];

  # Idempotent pool + state bring-up: file vdev on the persistent root disk.
  systemd.services.demo-pool = {
    description = "Create/import the demo ZFS pool";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [
      zfs
      e2fsprogs
      coreutils
      util-linux
    ];
    script = ''
      if ! zpool list demo >/dev/null 2>&1; then
        if [ -f /root/demo-vdev.img ]; then
          zpool import -d /root demo
        else
          truncate -s 8G /root/demo-vdev.img
          zpool create -f -O xattr=sa -O acltype=posixacl -O compression=zstd \
            -m none demo /root/demo-vdev.img
          zfs create -o mountpoint=/demo/shared demo/shared
          zfs create -p -V 2G demo/zvols/pg
          udevadm settle
          mkfs.ext4 -q /dev/zvol/demo/zvols/pg
        fi
      fi
    '';
  };

  # The "service IP": what the outside world (dragon :8080) talks to.
  # Cutover repoints it. Stand-in for the DD5 service-MAC takeover.
  systemd.services.demo-vip = {
    description = "Demo service VIP (socat -> active slot)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      EnvironmentFile = "-/var/lib/demo/vip.env";
      # systemd ExecStart can't do ''${VAR:-default} — wrap in a shell.
      ExecStart = pkgs.writeShellScript "demo-vip" ''
        exec ${pkgs.socat}/bin/socat TCP-LISTEN:8000,fork,reuseaddr,bind=0.0.0.0 "TCP:127.0.0.1:''${VIP_TARGET_PORT:-13001}"
      '';
      Restart = "always";
    };
  };

  # slot-quiesce/clean-shutdown plumbing: the host sshes into slots.
  environment.etc."demo-ssh-key" = {
    source = ../keys/demo-ssh-key;
    mode = "0600";
  };

  environment.systemPackages = [
    slotRun
    slotStop
    vipSet
    cutover
    demoStatus
    pkgs.zfs
    pkgs.curl
  ];

  users.motd = ''

    ┌─────────────────────────────────────────────────────────────┐
    │ DEMO HOST (beefcake-host stand-in, Model B)                 │
    │                                                             │
    │   demo-status                 what's running, pool state    │
    │   slot-run blue               start blue with REAL state    │
    │   slot-run green validate     green vs CLONES (egress cut)  │
    │   slot-stop green             stop + discard clones         │
    │   cutover green               the real thing (+ rollback:   │
    │                               cutover blue)                 │
    │                                                             │
    │ slots: ssh -p 12201/12202 root@localhost (blue/green)       │
    │ VIP :8000 → active slot's vaultwarden (dragon :8080)        │
    └─────────────────────────────────────────────────────────────┘
  '';

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../keys/demo-ssh-key.pub ];
  networking.firewall.enable = false;
}
