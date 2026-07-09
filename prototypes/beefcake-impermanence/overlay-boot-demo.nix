# Driver for P-overlay M2: build the disko image for ./overlay-boot-config.nix,
# boot it under qemu/OVMF, and assert the system booted with /nix/store as an
# OverlayFS (RO base lower + RW upper), runs normally, and accepts a NEW store
# path into the UPPER (not the base). Then reboot and prove the base store + the
# upper delta persist while the root wipes (the guest blue/green shape).
#
# Run with:  nix run .#overlay-boot-demo
{ pkgs, overlaySystem }:
pkgs.writeShellApplication {
  name = "overlay-boot-demo";
  runtimeInputs = [
    pkgs.qemu
    pkgs.openssh
    pkgs.coreutils
  ];
  text = ''
    work=$(mktemp -d)
    trap 'kill %1 2>/dev/null || true; rm -rf "$work"' EXIT
    cd "$work"

    echo "== building disko image (build VM; a few minutes) =="
    ${overlaySystem.config.system.build.diskoImagesScript} --build-memory 4096

    img=$(find . -maxdepth 1 \( -name '*.raw' -o -name '*.qcow2' \) -printf '%f\n' | head -1)
    echo "== image built: $img =="

    key=$work/demo-ssh-key
    cp ${./keys/demo-ssh-key} "$key"
    chmod 600 "$key"
    SSH_OPTS=(-i "$key" -p 2222 -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o ConnectTimeout=2 root@127.0.0.1)

    boot_vm() {
      qemu-system-x86_64 \
        -machine q35,accel=kvm -cpu host -m 4096 -smp 2 \
        -bios ${pkgs.OVMF.fd}/FV/OVMF.fd \
        -drive if=virtio,format="''${img##*.}",file="$img" \
        -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 \
        -device virtio-net-pci,netdev=n0 \
        -display none -serial file:serial.log &
    }
    wait_ssh() {
      for i in $(seq 90); do
        if ssh "''${SSH_OPTS[@]}" true 2>/dev/null; then return 0; fi
        if [ $((i % 15)) -eq 0 ]; then echo "  ... waiting for ssh ($((i * 4))s)"; fi
        sleep 2
      done
      echo "ssh never came up; serial tail:"; tail -60 serial.log; exit 1
    }

    echo "== boot 1 =="
    boot_vm
    wait_ssh

    echo "== assert: /nix/store IS an overlay mount =="
    # overlay-nix-store is ordered before nix-daemon but races sshd (both under
    # multi-user); wait for it to settle rather than check once.
    # /nix/store carries stacked mounts (base zfs + our overlay on top); the
    # EFFECTIVE (topmost) layer is the last line findmnt prints.
    fstype=""
    for _ in $(seq 30); do
      fstype=$(ssh "''${SSH_OPTS[@]}" 'findmnt -n -o FSTYPE /nix/store | tail -n1' || true)
      [ "$fstype" = overlay ] && break
      sleep 2
    done
    echo "  /nix/store effective fstype: $fstype"
    if [ "$fstype" != overlay ]; then
      echo "FAIL: /nix/store is not an overlay (got '$fstype')"
      echo "--- overlay-nix-store status ---"
      ssh "''${SSH_OPTS[@]}" 'systemctl status overlay-nix-store.service --no-pager -l 2>&1 | head -30' || true
      echo "--- overlay-nix-store journal ---"
      ssh "''${SSH_OPTS[@]}" 'journalctl -u overlay-nix-store --no-pager 2>&1 | tail -30' || true
      echo "--- nix mounts ---"
      ssh "''${SSH_OPTS[@]}" 'findmnt | grep -E "nix|overlay" || true' || true
      exit 1
    fi

    echo "== assert: system booted + converged FROM the overlay store =="
    sys=$(ssh "''${SSH_OPTS[@]}" 'systemctl is-system-running' || true)
    echo "  is-system-running: $sys"
    case "$sys" in running|degraded) ;; *)
      echo "FAIL: system did not converge on the overlay store (state=$sys)"
      ssh "''${SSH_OPTS[@]}" 'systemctl list-units --state=failed,activating --no-legend | head' || true
      exit 1 ;;
    esac
    # the running system's own toplevel must resolve through the overlay
    ssh "''${SSH_OPTS[@]}" 'test -e "$(readlink -f /run/current-system)/sw/bin/bash"' \
      || { echo "FAIL: current-system unreadable through the overlay"; exit 1; }

    echo "== assert: a NEW store path lands in the UPPER, not the base lower =="
    newpath=$(ssh "''${SSH_OPTS[@]}" 'echo overlay-delta-$(date +%s%N) > /tmp/f && nix-store --add /tmp/f' || true)
    echo "  added: $newpath"
    bn=$(basename "$newpath")
    # shellcheck disable=SC2029  # $bn expands client-side into the remote test — intended.
    # The definitive proof it wrote to the UPPER: overlayfs directs all writes
    # to upperdir, so a path physically present under /nix-upper/store went to
    # the delta, not the base. (We don't negative-check /nix/.store-lower — the
    # overlay propagates to that bind's peer group, so it shows the merged view,
    # not the pure base; a false "leak".)
    # shellcheck disable=SC2029
    ssh "''${SSH_OPTS[@]}" "test -e /nix-upper/store/$bn" \
      || { echo "FAIL: new path not physically in the upper (/nix-upper/store/$bn)"; exit 1; }
    # shellcheck disable=SC2029
    ssh "''${SSH_OPTS[@]}" "test -e /nix/store/$bn" \
      || { echo "FAIL: new path not visible through the merged /nix/store"; exit 1; }
    echo "  new path physically in the upper delta + visible via the merged /nix/store — good"

    # marker on the ephemeral root (should vanish); the upper delta must survive
    ssh "''${SSH_OPTS[@]}" 'touch /root/ephemeral-marker'
    boot_id_1=$(ssh "''${SSH_OPTS[@]}" 'cat /proc/sys/kernel/random/boot_id')

    echo "== reboot =="
    ssh "''${SSH_OPTS[@]}" 'reboot' || true
    sleep 10
    wait_ssh
    boot_id_2=$(ssh "''${SSH_OPTS[@]}" 'cat /proc/sys/kernel/random/boot_id')
    [ "$boot_id_1" != "$boot_id_2" ] || { echo "FAIL: VM did not reboot"; exit 1; }

    echo "== boot 2: root wiped, overlay re-established, upper delta persisted =="
    if ssh "''${SSH_OPTS[@]}" 'test -e /root/ephemeral-marker'; then
      echo "FAIL: root did not wipe"; exit 1
    fi
    fstype2=""
    for _ in $(seq 30); do
      fstype2=$(ssh "''${SSH_OPTS[@]}" 'findmnt -n -o FSTYPE /nix/store | tail -n1' || true)
      [ "$fstype2" = overlay ] && break
      sleep 2
    done
    [ "$fstype2" = overlay ] || { echo "FAIL: /nix/store not overlay after reboot ($fstype2)"; exit 1; }
    # shellcheck disable=SC2029  # $bn expands client-side — intended.
    ssh "''${SSH_OPTS[@]}" "test -e /nix-upper/store/$bn && test -e /nix/store/$bn" \
      || { echo "FAIL: upper delta path did not persist the reboot"; exit 1; }

    ssh "''${SSH_OPTS[@]}" 'poweroff' || true
    echo
    echo "PASS: booted on an overlaid /nix/store (RO base + RW upper); system converged;"
    echo "      new store paths isolate to the upper; root wipes, base+upper persist."
  '';
}
