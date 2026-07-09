# beefcake-host — Phase 3 thin hypervisor (design doc §2, open-Q#4 = libvirt +
# NixVirt). This is the box's REAL OS after the cutover: a deliberately tiny,
# impermanent NixOS host whose only jobs are (1) own the disks, (2) run today's
# beefcake config as a libvirt GUEST, (3) bridge the guest onto the LAN with the
# service MAC. Everything that is "beefcake the service host" lives in the guest.
#
# STATUS: increment 1 — the thin host itself (boot/disk/net/libvirtd/monitoring),
# NOT YET DEPLOYED. Validated on dragon via a nested VM. The GUEST domain
# (beefcake-guest, /nix overlay per overlay-nix M1, zstorage virtiofs shares,
# service-MAC tap) is the NEXT increment; wired in via NixVirt below where marked.
#
# Registered in packages/hosts/default.nix with the impermanence + NixVirt
# modules as extraModules.
{
  config,
  lib,
  pkgs,
  hardware,
  nixvirt,
  ...
}:
let
  # The guest domain, declared with NixVirt. storage_vol is the guest OS disk —
  # a zvol on the host that holds the guest's rpool (root@blank + the /nix base
  # closure + the per-slot /nix-upper + /persist). Provisioned at cutover by
  # building beefcake-guest into an image and writing it to the zvol (runbook).
  # The service MAC — whichever slot holds it answers as beefcake (192.168.0.9).
  serviceMac = "b8:ca:3a:6d:2d:24";

  # virtiofs share of a host dir into the guest (Model B). The guest mounts it
  # by the target `dir` tag (see guest-hardware.nix). `srcDir` is the host path
  # (the live dataset for the active slot, a CLONE for a validation slot).
  virtiofsShare = srcDir: tag: {
    type = "mount";
    accessmode = "passthrough";
    # driver TYPE selects virtiofs; driver *name* is silently ignored and
    # libvirt falls back to virtio-9p (caught in the nested test's qemu args —
    # the guest's fsType=virtiofs mounts would never match a 9p device).
    driver.type = "virtiofs";
    binary = {
      path = "${pkgs.virtiofsd}/bin/virtiofsd";
      xattr = true;
    };
    source.dir = srcDir;
    target.dir = tag;
  };

  # A slot domain. `slot` = blue|green. `mac`/`bridge` differ for the isolated
  # validation boot (a non-service MAC on a validation bridge, egress-cut) vs
  # the production boot (the service MAC on br0). `sharePrefix` lets a validation
  # slot mount CLONES (…-validate) instead of the live datasets.
  mkSlotDomain =
    {
      slot,
      uuid,
      mac,
      bridge,
      sharePrefix ? "",
    }:
    let
      base = nixvirt.lib.domain.templates.linux {
        name = "beefcake-${slot}";
        inherit uuid;
        memory = {
          count = 200;
          unit = "GiB";
        };
        vcpu.count = 36;
        storage_vol = "/dev/zvol/rpool/beefcake-${slot}";
        bridge_name = bridge;
        net_iface_mac = mac;
      };
    in
    base
    // {
      # UEFI: the slot image is GPT + ESP + systemd-boot — the template's default
      # (SeaBIOS) cannot boot it. Explicit OVMF pflash (store-pinned, no reliance
      # on libvirt firmware auto-selection); per-domain nvram from the VARS
      # template. Found by the nested integration test.
      os = base.os // {
        loader = {
          readonly = true;
          type = "pflash";
          path = "${pkgs.OVMF.fd}/FV/OVMF_CODE.fd";
        };
        nvram = {
          template = "${pkgs.OVMF.fd}/FV/OVMF_VARS.fd";
          path = "/var/lib/libvirt/qemu/nvram/beefcake-${slot}.fd";
        };
      };
      # virtiofs requires guest RAM be shared (memfd + shared access).
      memoryBacking = {
        source.type = "memfd";
        access.mode = "shared";
      };
      devices = base.devices // {
        # The slot zvol is a BLOCK device holding a RAW image. The template
        # emits type=file + driver type=qcow2 — qemu refuses ('file' driver
        # requires a regular file) and would misparse raw as qcow2. Rewrite the
        # data disk to block/dev/raw; drop the install cdrom (never needed).
        # All caught by the nested integration test.
        disk = map (
          d:
          d
          // {
            type = "block";
            source.dev = "/dev/zvol/rpool/beefcake-${slot}";
            driver = d.driver // {
              type = "raw";
            };
          }
        ) (builtins.filter (d: d.device == "disk") base.devices.disk);
        filesystem = [
          (virtiofsShare "/storage${sharePrefix}" "storage")
          (virtiofsShare "/var/lib/containers${sharePrefix}" "containers")
          (virtiofsShare "/var/lib/private${sharePrefix}" "varlib-private")
        ];
        # Headless server guest (third bug caught by the nested integration
        # test): the template's spice graphics with GL REQUIRE DRM render nodes
        # ("No DRM render nodes available" — absent on a headless server) and
        # the domain refuses to start. Strip spice/sound/audio; plain VGA; a
        # pty serial console — which IS the §5 recovery path (virsh console).
        graphics = null;
        sound = null;
        audio = null;
        video.model = {
          type = "vga";
          primary = true;
        };
        channel = [
          {
            type = "unix";
            target = {
              type = "virtio";
              name = "org.qemu.guest_agent.0";
            };
          }
        ];
        redirdev = [ ]; # the template's 4 spicevmc USB redirs — spice is gone
        serial = [ { type = "pty"; } ];
        console = [
          {
            type = "pty";
            target.type = "serial";
          }
        ];
      };
    };

  # blue = the initial ACTIVE slot (service MAC on br0, live shares).
  blueDomain = mkSlotDomain {
    slot = "blue";
    uuid = "b1000000-beef-cafe-0000-000000000001";
    mac = serviceMac;
    bridge = "br0";
  };

  # The green production + validation domain XMLs are generated for the cutover
  # tool to `virsh define` on demand (green is NOT autostarted).
  greenProdXML = nixvirt.lib.domain.writeXML (mkSlotDomain {
    slot = "green";
    uuid = "b1000000-beef-cafe-0000-000000000002";
    mac = serviceMac; # takes the service MAC AT CUTOVER (blue is stopped first)
    bridge = "br0";
  });
  greenValidateXML = nixvirt.lib.domain.writeXML (mkSlotDomain {
    slot = "green";
    uuid = "b1000000-beef-cafe-0000-000000000002";
    mac = "b8:ca:3a:6d:2d:99"; # NON-service MAC — never collides on the LAN
    bridge = "virbr-validate"; # isolated, egress-cut validation network
    sharePrefix = "-validate"; # mount the ZFS CLONES, not the live datasets
  });

  # beefcake-cutover: the blue/green tool (ports the proven demo logic —
  # prototypes/.../demo — to the real host: libvirt/NixVirt domains + real
  # zstorage clones + the service-MAC move). Runtime-validated on the thin host
  # itself (the demo already proved the validate/cutover/rollback flow).
  beefcake-cutover = pkgs.writeShellApplication {
    name = "beefcake-cutover";
    runtimeInputs = [
      pkgs.libvirt
      pkgs.zfs
      pkgs.gnugrep
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail
      MARKER=/persist/beefcake-active-slot
      DS=(storage var/lib/containers var/lib/private)   # zstorage share datasets
      active() { cat "$MARKER" 2>/dev/null || echo blue; }
      other() { [ "$(active)" = blue ] && echo green || echo blue; }

      cmd="''${1:-status}"
      case "$cmd" in
        status)
          echo "active slot: $(active)"
          virsh list --all || true
          ;;
        validate)
          # Validate the candidate (green) against CLONES of the live state on an
          # isolated network — never touches production. QUIESCE the active slot
          # first (sqlite WAL / fsync — see DD6) so the clone is consistent.
          echo "== quiescing $(active) + snapshotting zstorage =="
          virsh domfsfreeze "beefcake-$(active)" || true
          for d in "''${DS[@]}"; do
            zfs destroy -r "zstorage/$d-validate" 2>/dev/null || true
            zfs destroy "zstorage/$d@validate" 2>/dev/null || true
            zfs snapshot "zstorage/$d@validate"
            zfs clone "zstorage/$d@validate" "zstorage/$d-validate"
          done
          virsh domfsthaw "beefcake-$(active)" || true
          echo "== booting green against clones (isolated net) =="
          virsh define ${greenValidateXML}
          virsh start beefcake-green
          echo "green booting for validation; run per-service checks, then: beefcake-cutover validate-done"
          ;;
        validate-done)
          virsh destroy beefcake-green 2>/dev/null || true
          virsh undefine beefcake-green 2>/dev/null || true
          for d in "''${DS[@]}"; do
            zfs destroy -r "zstorage/$d-validate" 2>/dev/null || true
            zfs destroy "zstorage/$d@validate" 2>/dev/null || true
          done
          echo "validation clones discarded; production untouched"
          ;;
        cutover)
          target=green
          [ "$(active)" = green ] && target=blue
          echo "== pre-cutover zstorage snapshot (rollback bound) =="
          zfs snapshot -r "zstorage@pre-cutover-$target" || true
          echo "== stop $(active), start $target with the service MAC + live shares =="
          virsh shutdown "beefcake-$(active)" || true
          for _ in $(seq 60); do virsh domstate "beefcake-$(active)" 2>/dev/null | grep -qx "shut off" && break; sleep 2; done
          if [ "$target" = green ]; then virsh define ${greenProdXML}; fi
          virsh start "beefcake-$target"
          echo "$target" > "$MARKER"
          echo "cutover to $target done; verify, then 'beefcake-cutover rollback' if needed"
          ;;
        rollback)
          # symmetric: bring the other slot back up as active
          prev=$(other)
          virsh shutdown "beefcake-$(active)" || true
          for _ in $(seq 60); do virsh domstate "beefcake-$(active)" 2>/dev/null | grep -qx "shut off" && break; sleep 2; done
          virsh start "beefcake-$prev"
          echo "$prev" > "$MARKER"
          echo "rolled back to $prev"
          ;;
        *) echo "usage: beefcake-cutover status|validate|validate-done|cutover|rollback"; exit 1 ;;
      esac
    '';
  };
in
{
  imports = [
    hardware.common-cpu-intel
  ];

  networking.hostName = "beefcake-host";
  # SAME hostId as bare-metal beefcake (and the guest): zstorage + rpool were
  # last attached under 541ede55 and are NOT exported at shutdown — a different
  # hostId would make the host's imports refuse ("in use from another system").
  # Safe to share: host and guest never import the same pool (the guest only
  # force-imports its own inner zvol pool). Caught in cutover pre-flight.
  networking.hostId = "541ede55";

  # ---- boot / disk: same hardware as beefcake (Dell R720xd), SSD ZFS mirror
  #      root, dual ESPs, HBA + KVM. Mirrors packages/hosts/beefcake/hardware.nix
  #      but WITHOUT declaring /nix on zstorage — the host's /nix rides its own
  #      root pool (tiny closure); zstorage is imported for SHARING to the guest,
  #      not for the host's own /nix. ----
  boot = {
    supportedFilesystems.zfs = true;
    initrd.supportedFilesystems.zfs = true;
    initrd.availableKernelModules = [
      "ehci_pci"
      "mpt3sas" # the one IT-mode HBA driving every disk
      "usbhid"
      "sd_mod"
    ];
    kernelModules = [ "kvm-intel" ];
    # intel_iommu on for the Phase-5 HBA-passthrough option (BIOS VT-d already
    # enabled); harmless otherwise.
    kernelParams = [
      "nohibernate"
      "intel_iommu=on"
    ];
    loader.systemd-boot.enable = true;
    loader.systemd-boot.configurationLimit = 20;
    loader.efi.canTouchEfiVariables = true;
    # Mirror ESP-A onto ESP-B after install so either SSD boots (as beefcake).
    loader.systemd-boot.extraInstallCommands = ''
      espB=/dev/disk/by-partlabel/ESP-B
      if [ -e "$espB" ]; then
        m=$(mktemp -d)
        ${pkgs.util-linux}/bin/mount "$espB" "$m"
        ${pkgs.rsync}/bin/rsync -a --delete /boot/ "$m"/
        ${pkgs.util-linux}/bin/umount "$m"
        rmdir "$m"
      fi
    '';
  };

  # The host root is impermanent on its own rpool dataset. lyte.impermanence
  # (packages/hosts/beefcake/impermanence.nix is beefcake-specific; the host
  # reuses the SAME proven mechanism — @blank rollback initrd unit + /persist).
  # TODO(increment): factor the impermanence.nix mechanism into a shared module
  # so beefcake-host and beefcake(guest) both consume it instead of copying.
  # For now the host's persist set is intentionally tiny (identity + libvirt).
  # The host gets its OWN root + persist datasets (rpool/local/host-root@blank,
  # rpool/host-persist — created in cutover prep), NOT beefcake's
  # rpool/local/root + rpool/persist: sharing persist would hand the host
  # beefcake's machine-id (now the GUEST's identity -> DHCP-DUID collision on
  # the same bridge) and gen-609 fallback must keep its datasets untouched.
  # /nix reuses zstorage/nix exactly like today's beefcake (imported in
  # initrd — proven on this machine; deploy --boot lands the host closure
  # there, so it is populated BEFORE the first host boot; a fresh rpool
  # dataset would be EMPTY at boot). Caught in cutover pre-flight.
  fileSystems = {
    "/" = {
      device = "rpool/local/host-root";
      fsType = "zfs";
    };
    "/persist" = {
      device = "rpool/host-persist";
      fsType = "zfs";
      neededForBoot = true;
    };
    "/boot" = {
      device = "/dev/disk/by-partlabel/ESP-A";
      fsType = "vfat";
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
    };
    "/nix" = {
      device = "zstorage/nix";
      fsType = "zfs";
      neededForBoot = true;
    };
  };

  # The proven impermanence machinery (impermanence.nix + rollback-demo),
  # targeting the HOST's datasets. Wipe host-root to @blank each boot; seed a
  # host-own machine-id (self-generating on first boot -> fresh host identity,
  # distinct from the guest's) before switch-root.
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.services.rollback-host-root = {
    description = "Rollback rpool/local/host-root to @blank (impermanence)";
    wantedBy = [ "initrd.target" ];
    requires = [ "zfs-import-rpool.service" ];
    after = [ "zfs-import-rpool.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = "zfs rollback -r rpool/local/host-root@blank";
  };
  boot.initrd.systemd.services.persist-machine-id = {
    description = "Seed host /etc/machine-id from /persist before switch-root";
    wantedBy = [ "initrd.target" ];
    requires = [
      "sysroot.mount"
      "sysroot-persist.mount"
    ];
    after = [
      "rollback-host-root.service"
      "sysroot.mount"
      "sysroot-persist.mount"
    ];
    before = [ "initrd-switch-root.target" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /sysroot/persist/etc /sysroot/etc
      if [ ! -s /sysroot/persist/etc/machine-id ]; then
        tr -d - < /proc/sys/kernel/random/uuid > /sysroot/persist/etc/machine-id
      fi
      cp /sysroot/persist/etc/machine-id /sysroot/etc/machine-id
      chmod 0444 /sysroot/etc/machine-id
    '';
  };

  # Host ssh identity persists across the root wipe (self-generates into
  # /persist on first boot). The #727 /var-perms guard rides along.
  services.openssh.hostKeys = [
    {
      path = "/persist/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];
  systemd.tmpfiles.rules = [
    "d /var 0755 root root -"
    "d /var/lib 0755 root root -"
    "d /var/cache 0755 root root -"
  ];

  # Host owns zstorage: import it (do NOT mount its datasets on the host beyond
  # what it shares) so the host can virtiofs-share datasets into the guest.
  boot.zfs.extraPools = [ "zstorage" ];

  # ---- networking: br0 enslaves eno1; the guest's virtio NIC rides br0 with
  #      the SERVICE MAC (b8:ca:3a:6d:2d:24) to keep 192.168.0.9 + the v6 GUA.
  #      The HOST takes its own DHCP address ON br0 with a PINNED, distinct MAC
  #      — no eno2 cable required for management (autonomous-cutover req). ----
  networking = {
    useDHCP = false;
    bridges.br0.interfaces = [ "eno1" ];
    # CRITICAL (bug #6, caught in the autonomous-cutover review): a Linux bridge
    # inherits the MAC of its (lowest) enslaved NIC — br0 would come up wearing
    # eno1's burned-in MAC, which IS the service MAC the GUEST carries, and the
    # two would fight over 192.168.0.9 (ARP flapping). Pin br0 a distinct,
    # locally-administered MAC; the router sees the host as its own device and
    # DHCPs it a separate address (reserve it in the router when known).
    interfaces.br0 = {
      macAddress = "0a:be:ef:b0:57:01"; # locally-administered; "beef host 1"
      useDHCP = true;
    };
    # eno2/3/4 stay unplugged; plugging eno2 remains an OPTIONAL second mgmt
    # path (interfaces.eno2.useDHCP) but is deliberately not required.
  };

  # ---- virtualization: libvirt + NixVirt (design open-Q#4) ----
  virtualisation.libvirtd = {
    enable = true;
    qemu.runAsRoot = false;
    qemu.swtpm.enable = true;
    onShutdown = "shutdown"; # clean guest poweroff (DD6: never SIGTERM the VMM)
  };
  # virtiofsd for sharing host zstorage datasets into the guest (Model B).
  virtualisation.libvirtd.qemu.vhostUserPackages = [ pkgs.virtiofsd ];

  # The guest domain, declared (NixVirt). `active` autostarts the blue slot; its
  # OS closure is beefcake-guest (packages/hosts/beefcake/guest-hardware.nix),
  # written to the /dev/zvol/rpool/beefcake-blue disk at cutover. virtiofs shares
  # feed it the host's zstorage datasets; the tap carries the service MAC.
  # (Green slot + the cutover tool are Phase 4.)
  virtualisation.libvirt = {
    enable = true;
    connections."qemu:///system" = {
      domains = [
        {
          active = true; # blue autostarts as the active slot
          definition = nixvirt.lib.domain.writeXML blueDomain;
        }
      ];
      # Isolated, egress-cut network for green validation (no service MAC ever
      # reaches the LAN here). green-production uses br0 directly (not a libvirt
      # network), so this exists only for the validation boot.
      networks = [
        {
          active = true;
          definition = nixvirt.lib.network.writeXML {
            name = "validate";
            uuid = "c0000000-beef-cafe-0000-0000000000aa";
            bridge.name = "virbr-validate";
            # no <forward> → isolated (no NAT/egress); guests talk only to each
            # other + the host. Matches the demo's egress-cut validation slot.
          };
        }
      ];
    };
  };

  # The cutover tool + the active-slot marker (persisted across the host's
  # ephemeral root so an unattended host reboot restarts the right slot).
  environment.systemPackages = [ beefcake-cutover ];

  # ---- monitoring: hardware lives with the host (smartd/IPMI/node-exporter),
  #      shipped to the guest's OpenObserve (design §5). ----
  services.smartd.enable = true;
  hardware.enableRedistributableFirmware = true;

  # ---- minimal: sshd for host access; NO beefcake services (those are the
  #      guest). Host access is the guest-independent recovery path (§5). ----
  services.openssh.enable = true;

  # The host's /persist set is deliberately tiny: its identity + libvirt state
  # + the active-slot marker. (Guest state is the guest's problem.)
  environment.persistence."/persist" = {
    hideMounts = true;
    files = [ ];
    directories = [
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/libvirt" # domain defs / nvram / swtpm state
    ];
  };

  system.stateVersion = "26.05";
}
