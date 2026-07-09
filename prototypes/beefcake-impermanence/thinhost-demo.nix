# Driver for the P4 thin-host integration test: boot thinhost-config.nix (the
# beefcake-host stack in miniature) on dragon, provision the mini-guest EXACTLY
# the cutover-runbook way (zpool create → zfs create -V → dd the disko image
# onto the zvol), `virsh start` it, and assert every integration point the real
# cutover depends on:
#   - the NixVirt-defined domain actually RUNS under libvirtd
#   - the guest boots its RAW zvol image via OVMF pflash (the two bugs this
#     test already caught at review: qcow2-driver + missing UEFI loader)
#   - the guest's /nix/store is the OverlayFS (M2, now under libvirt)
#   - the virtiofs share is readable end-to-end (host marker visible in guest)
#   - the service-MAC NIC is named eno1 and got the RESERVED IP from the
#     host's dnsmasq (the router-reservation flow in miniature)
#
# Run with:  nix run .#thinhost-demo
{
  pkgs,
  thinhostSystem,
  miniGuestSystem,
}:
pkgs.writeShellApplication {
  name = "thinhost-demo";
  runtimeInputs = [
    pkgs.openssh
    pkgs.coreutils
  ];
  text = ''
    work=$(mktemp -d)
    trap 'kill %1 2>/dev/null || true; rm -rf "$work" /tmp/thinhost-guest-img' EXIT
    cd "$work"

    echo "== building the mini-guest disko image (the slot-OS-image flow) =="
    imgdir=$work/img
    mkdir -p "$imgdir"
    (cd "$imgdir" && ${miniGuestSystem.config.system.build.diskoImagesScript} --build-memory 4096)
    img=$(find "$imgdir" -maxdepth 1 \( -name '*.raw' -o -name '*.qcow2' \) | head -1)
    echo "== image built: $img =="
    mkdir -p /tmp/thinhost-guest-img
    install -m 0644 "$img" /tmp/thinhost-guest-img/guest.raw

    key=$work/demo-ssh-key
    cp ${./keys/demo-ssh-key} "$key"
    chmod 600 "$key"
    SSH_OPTS=(-i "$key" -p 2400 -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 root@127.0.0.1)

    echo "== booting the thin host VM =="
    export NIX_DISK_IMAGE=$work/thinhost.qcow2
    export QEMU_NET_OPTS="hostfwd=tcp:127.0.0.1:2400-:22"
    ${thinhostSystem.config.system.build.vm}/bin/run-thinhost-vm \
      -display none -serial "file:$work/serial.log" &

    wait_ssh() {
      for i in $(seq 90); do
        if ssh "''${SSH_OPTS[@]}" true 2>/dev/null; then return 0; fi
        if [ $((i % 15)) -eq 0 ]; then echo "  ... waiting for thin-host ssh ($((i * 4))s)"; fi
        sleep 2
      done
      echo "thin host ssh never came up; serial tail:"; tail -60 "$work/serial.log"; exit 1
    }
    wait_ssh
    echo "== thin host up =="

    # nested-ssh helper installed on the thin host (thinhost -> guest)
    ssh "''${SSH_OPTS[@]}" 'printf "#!/bin/sh\nexec ssh -i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=3 root@10.99.0.9 \"\$@\"\n" > /root/g && chmod +x /root/g'

    echo "== waiting for libvirtd + the NixVirt-defined domain =="
    for i in $(seq 30); do
      if ssh "''${SSH_OPTS[@]}" 'virsh dominfo mini-guest >/dev/null 2>&1'; then break; fi
      if [ "$i" = 30 ]; then
        echo "FAIL: domain never defined (NixVirt module)"
        ssh "''${SSH_OPTS[@]}" 'systemctl status nixvirt.service --no-pager -l 2>&1 | head -20; journalctl -u libvirtd --no-pager 2>&1 | tail -20' || true
        exit 1
      fi
      sleep 4
    done
    echo "  domain defined (NixVirt module works under libvirtd)"

    echo "== provisioning the slot zvol EXACTLY the runbook way =="
    ssh "''${SSH_OPTS[@]}" 'zpool create -f rpool /dev/vdb && zfs create -V 10G rpool/mini'
    ssh "''${SSH_OPTS[@]}" 'dd if=/guest-img/guest.raw of=/dev/zvol/rpool/mini bs=4M conv=sparse,fsync status=none && echo "image written to zvol"'

    echo "== virsh start mini-guest =="
    if ! ssh "''${SSH_OPTS[@]}" 'virsh start mini-guest'; then
      echo "FAIL: domain would not start"
      ssh "''${SSH_OPTS[@]}" 'journalctl -u libvirtd --no-pager | tail -30; ls -la /var/log/libvirt/qemu/ 2>/dev/null; cat /var/log/libvirt/qemu/mini-guest.log 2>/dev/null | tail -30' || true
      exit 1
    fi

    echo "== waiting for the guest (nested ssh via the service IP 10.99.0.9) =="
    for i in $(seq 90); do
      if ssh "''${SSH_OPTS[@]}" '/root/g true 2>/dev/null'; then break; fi
      if [ "$i" = 90 ]; then
        echo "FAIL: guest never became reachable on the reserved IP"
        ssh "''${SSH_OPTS[@]}" 'virsh list --all; virsh domifaddr mini-guest 2>/dev/null; cat /var/log/libvirt/qemu/mini-guest.log 2>/dev/null | tail -40; journalctl -u dnsmasq --no-pager | tail -20' || true
        exit 1
      fi
      if [ $((i % 15)) -eq 0 ]; then echo "  ... waiting for guest ($((i * 4))s)"; fi
      sleep 4
    done
    echo "  guest reachable at 10.99.0.9 (service-MAC DHCP reservation works)"

    echo "== assertions inside the guest =="
    fstype=$(ssh "''${SSH_OPTS[@]}" "/root/g 'findmnt -n -o FSTYPE /nix/store | tail -n1'" || true)
    echo "  /nix/store effective fstype: $fstype"
    [ "$fstype" = overlay ] || { echo "FAIL: guest /nix/store not overlay"; exit 1; }

    marker=$(ssh "''${SSH_OPTS[@]}" "/root/g 'cat /storage/marker 2>/dev/null'" || true)
    echo "  /storage/marker: $marker"
    [ "$marker" = thin-host-shared-data ] || { echo "FAIL: virtiofs share not readable in guest"; exit 1; }

    mac=$(ssh "''${SSH_OPTS[@]}" "/root/g 'cat /sys/class/net/eno1/address 2>/dev/null'" || true)
    echo "  eno1 mac: $mac"
    [ "$mac" = b8:ca:3a:6d:2d:24 ] || { echo "FAIL: NIC not named eno1 by the service MAC"; exit 1; }

    ip=$(ssh "''${SSH_OPTS[@]}" "/root/g 'ip -4 -br addr show eno1'" || true)
    echo "  eno1 addr: $ip"
    case "$ip" in *10.99.0.9*) ;; *) echo "FAIL: guest did not get the reserved service IP"; exit 1;; esac

    sysstate=$(ssh "''${SSH_OPTS[@]}" "/root/g 'systemctl is-system-running'" || true)
    echo "  guest is-system-running: $sysstate"
    case "$sysstate" in running|degraded) ;; *) echo "FAIL: guest did not converge ($sysstate)"; exit 1;; esac

    state=$(ssh "''${SSH_OPTS[@]}" 'virsh domstate mini-guest' || true)
    echo "  virsh domstate: $state"
    [ "$state" = running ] || { echo "FAIL: domain not running per libvirt"; exit 1; }

    ssh "''${SSH_OPTS[@]}" '/root/g poweroff 2>/dev/null; sleep 3; poweroff' 2>/dev/null || true
    echo
    echo "PASS: thin-host integration — NixVirt domain runs; RAW zvol image boots via"
    echo "      OVMF; guest /nix is the overlay; virtiofs share readable; service-MAC"
    echo "      NIC named eno1 + got the reserved IP; guest converged."
  '';
}
