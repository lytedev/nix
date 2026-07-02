# Driver for P1b: build the disko image for ./rollback-config.nix, boot it
# under qemu/OVMF, exercise a write to /root and /persist, reboot, and assert
# the root write vanished while /persist survived.
#
# Run with:  nix run .#rollback-demo
{ pkgs, rollbackSystem }:
pkgs.writeShellApplication {
  name = "rollback-demo";
  runtimeInputs = [
    pkgs.qemu
    pkgs.openssh
    pkgs.coreutils
  ];
  text = ''
    work=$(mktemp -d)
    trap 'kill %1 2>/dev/null || true; rm -rf "$work"' EXIT
    cd "$work"

    echo "== building disko image (runs a build VM; a few minutes) =="
    ${rollbackSystem.config.system.build.diskoImagesScript} --build-memory 4096

    img=$(find . -maxdepth 1 \( -name '*.raw' -o -name '*.qcow2' \) -printf '%f\n' | head -1)
    echo "== image built: $img =="

    key=$work/demo-ssh-key
    cp ${./keys/demo-ssh-key} "$key"
    chmod 600 "$key"
    SSH_OPTS=(-i "$key" -p 2222 -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2 root@127.0.0.1)

    echo "== booting VM (EFI/systemd-boot -> systemd-initrd -> zfs rollback) =="
    qemu-system-x86_64 \
      -machine q35,accel=kvm -cpu host -m 2048 -smp 2 \
      -bios ${pkgs.OVMF.fd}/FV/OVMF.fd \
      -drive if=virtio,format="''${img##*.}",file="$img" \
      -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 \
      -device virtio-net-pci,netdev=n0 \
      -display none -serial file:serial.log &

    wait_ssh() {
      # ~4 min max: 60 tries x (2s connect timeout + 2s sleep)
      for i in $(seq 60); do
        if ssh "''${SSH_OPTS[@]}" true 2>/dev/null; then return 0; fi
        if [ $((i % 15)) -eq 0 ]; then echo "  ... still waiting for ssh ($((i * 4))s)"; fi
        sleep 2
      done
      echo "ssh never came up; serial log tail:"; tail -50 serial.log; exit 1
    }

    wait_ssh
    echo "== boot 1: seeding state =="
    ssh "''${SSH_OPTS[@]}" 'touch /root/ephemeral-marker; echo survives > /persist/keep; zfs list -o name,mountpoint'
    boot_id_1=$(ssh "''${SSH_OPTS[@]}" 'cat /proc/sys/kernel/random/boot_id')

    echo "== rebooting =="
    ssh "''${SSH_OPTS[@]}" 'reboot' || true
    sleep 10
    wait_ssh

    boot_id_2=$(ssh "''${SSH_OPTS[@]}" 'cat /proc/sys/kernel/random/boot_id')
    if [ "$boot_id_1" = "$boot_id_2" ]; then
      echo "FAIL: VM did not actually reboot"; exit 1
    fi

    echo "== boot 2: asserting rollback + persistence =="
    if ssh "''${SSH_OPTS[@]}" 'test -e /root/ephemeral-marker'; then
      echo "FAIL: /root/ephemeral-marker SURVIVED - rollback did not run"
      ssh "''${SSH_OPTS[@]}" 'journalctl -b | grep -i rollback | head' || true
      exit 1
    fi
    got=$(ssh "''${SSH_OPTS[@]}" 'cat /persist/keep')
    if [ "$got" != "survives" ]; then
      echo "FAIL: /persist/keep lost or wrong: $got"; exit 1
    fi
    ssh "''${SSH_OPTS[@]}" 'journalctl -b -u rollback-root --no-pager || true'
    ssh "''${SSH_OPTS[@]}" 'poweroff' || true

    echo
    echo "PASS: root wiped by initrd zfs rollback, /persist survived, host key stable"
  '';
}
