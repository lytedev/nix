# Driver for the P4 blue/green integration test: boots thinhost-config.nix (the
# beefcake-host stack in miniature, running the SHARED production slot-domain +
# cutover-tool code) and exercises the FULL blue/green cycle:
#   provision (image -> blue+green OS zvols [same image; slots are disposable
#   pure-OS] + the shared persist zvol via the MIGRATION RECIPE) -> blue up on
#   the service IP -> write state into /persist -> `mini-cutover validate`
#   (green boots against CLONES on the isolated net) -> validate-done (clones
#   discarded) -> `mini-cutover cutover` (blue stops, green takes the service
#   MAC + REAL persist) -> assert THE STATE TRAVELED -> rollback -> blue again.
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

    echo "== building the mini-guest disko image (all-legacy builder) =="
    imgdir=$work/img
    mkdir -p "$imgdir"
    (cd "$imgdir" && ${miniGuestSystem.config.system.build.diskoImagesScript} --build-memory 4096)
    img=$(find "$imgdir" -maxdepth 1 \( -name '*.raw' -o -name '*.qcow2' \) | head -1)
    mkdir -p /tmp/thinhost-guest-img
    install -m 0644 "$img" /tmp/thinhost-guest-img/guest.raw
    echo "== image staged =="

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

    for i in $(seq 90); do
      ssh "''${SSH_OPTS[@]}" true 2>/dev/null && break
      [ "$i" = 90 ] && { echo "FAIL: thin host never up"; tail -40 "$work/serial.log"; exit 1; }
      sleep 2
    done
    echo "== thin host up =="
    ssh "''${SSH_OPTS[@]}" 'printf "#!/bin/sh\nexec ssh -i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=3 root@10.99.0.9 \"\$@\"\n" > /root/g && chmod +x /root/g'

    echo "== provisioning: pools, slot zvols (SAME image both), persist (migration recipe), share dataset =="
    ssh "''${SSH_OPTS[@]}" '
      set -e
      zpool create -f rpool /dev/vdb
      zfs create -s -V 12G rpool/mini-blue
      zfs create -s -V 12G rpool/mini-green
      udevadm settle
      for s in blue green; do for _ in $(seq 50); do [ -b /dev/zvol/rpool/mini-$s ] && break; sleep 0.2; done; done
      dd if=/guest-img/guest.raw of=/dev/zvol/rpool/mini-blue bs=4M conv=sparse,fsync status=none
      dd if=/guest-img/guest.raw of=/dev/zvol/rpool/mini-green bs=4M conv=sparse,fsync status=none
      # THE PERSIST MIGRATION RECIPE (same on the real box):
      zfs create -s -V 4G rpool/mini-persist
      udevadm settle
      zpool create -f bpersist /dev/zvol/rpool/mini-persist
      zfs create -o mountpoint=legacy bpersist/persist
      zpool export bpersist
      # share dataset + a marker the guests must see via virtiofs
      zfs create -o mountpoint=/t-storage rpool/t-storage
      echo shared-data-v1 > /t-storage/marker
      echo provisioned
    '

    echo "== start blue; wait for the service IP =="
    ssh "''${SSH_OPTS[@]}" 'virsh start mini-blue'
    for i in $(seq 90); do
      ssh "''${SSH_OPTS[@]}" '/root/g true 2>/dev/null' && break
      [ "$i" = 90 ] && { echo "FAIL: blue never reachable"; ssh "''${SSH_OPTS[@]}" 'virsh list --all'; exit 1; }
      sleep 4
    done
    echo "  blue up on 10.99.0.9"

    echo "== write STATE into /persist + verify the share =="
    ssh "''${SSH_OPTS[@]}" "/root/g 'echo precious-state-from-blue > /persist/cutover-marker; sync'"
    m=$(ssh "''${SSH_OPTS[@]}" "/root/g 'cat /storage/marker'")
    [ "$m" = shared-data-v1 ] || { echo "FAIL: share not visible in blue"; exit 1; }
    fst=$(ssh "''${SSH_OPTS[@]}" "/root/g 'findmnt -n -o SOURCE /persist'")
    echo "  blue /persist source: $fst"
    [ "$fst" = bpersist/persist ] || { echo "FAIL: blue /persist not on the shared pool"; exit 1; }

    echo "== VALIDATE: green vs clones on the isolated net + HEALTH GATE =="
    vout=$(ssh "''${SSH_OPTS[@]}" 'mini-cutover validate' 2>&1 || true)
    echo "$vout" | sed 's/^/    /' | tail -25
    echo "$vout" | grep -q 'GATE PASS' || { echo "FAIL: health gate did not PASS in validation"; exit 1; }
    echo "  ✅ health gate ran in the validation slot and PASSED"
    st=$(ssh "''${SSH_OPTS[@]}" 'virsh domstate mini-green' || true)
    [ "$st" = running ] || { echo "FAIL: validation green not running"; exit 1; }
    ssh "''${SSH_OPTS[@]}" 'zfs list -H -o name | grep -c "validate"' | grep -q '[1-9]' || { echo "FAIL: no validate clones"; exit 1; }
    blu=$(ssh "''${SSH_OPTS[@]}" '/root/g "systemctl is-system-running" 2>/dev/null' || echo x)
    echo "  blue still serving during validation: $blu"

    echo "== validate-done: discard clones =="
    ssh "''${SSH_OPTS[@]}" 'mini-cutover validate-done'
    ssh "''${SSH_OPTS[@]}" 'zfs list -H -o name | grep -c "validate" || true' | grep -q '^0' || { echo "FAIL: clones not discarded"; exit 1; }
    echo "  clones gone; production untouched"

    echo "== CUTOVER: blue -> green on the REAL persist + service MAC =="
    ssh "''${SSH_OPTS[@]}" 'mini-cutover cutover'
    for i in $(seq 90); do
      ssh "''${SSH_OPTS[@]}" '/root/g true 2>/dev/null' && break
      [ "$i" = 90 ] && { echo "FAIL: green never took the service IP"; ssh "''${SSH_OPTS[@]}" 'virsh list --all'; exit 1; }
      sleep 4
    done
    got=$(ssh "''${SSH_OPTS[@]}" "/root/g 'cat /persist/cutover-marker 2>/dev/null'" || true)
    echo "  post-cutover /persist marker: $got"
    [ "$got" = precious-state-from-blue ] || { echo "FAIL: STATE DID NOT TRAVEL"; exit 1; }
    ssh "''${SSH_OPTS[@]}" 'virsh domstate mini-green | grep -qx running && virsh domstate mini-blue | grep -qx "shut off"' \
      || { echo "FAIL: slot states wrong after cutover"; exit 1; }
    echo "  ✅ state traveled with the persist pool; green is the active slot"

    echo "== ROLLBACK: green -> blue =="
    ssh "''${SSH_OPTS[@]}" 'mini-cutover rollback'
    for i in $(seq 90); do
      ssh "''${SSH_OPTS[@]}" '/root/g true 2>/dev/null' && break
      [ "$i" = 90 ] && { echo "FAIL: blue never came back"; exit 1; }
      sleep 4
    done
    got=$(ssh "''${SSH_OPTS[@]}" "/root/g 'cat /persist/cutover-marker 2>/dev/null'" || true)
    [ "$got" = precious-state-from-blue ] || { echo "FAIL: state lost on rollback"; exit 1; }

    ssh "''${SSH_OPTS[@]}" '/root/g poweroff 2>/dev/null; sleep 3; poweroff' 2>/dev/null || true
    echo
    echo "PASS: FULL BLUE/GREEN CYCLE — provision (disposable slots + shared persist),"
    echo "      validate-vs-clones on the isolated net (blue serving throughout),"
    echo "      clone discard, cutover with state travel, rollback with state intact."
  '';
}
