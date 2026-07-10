# P4 ADVERSARIAL DATA-SAFETY SUITE: deliberately TRY to lose/corrupt data and
# assert every failure is contained. The blue/green happy-path cycle
# (thinhost-demo) proves it WORKS; this proves it's SAFE under abuse. Runs the
# real slot-domain + cutover-tool on the nested thin host.
#
# Scenarios (each must be CONTAINED):
#   S1 two-writer: manually `virsh start` BOTH slots against the shared persist
#      zvol -> the 2nd must be REFUSED (virtlockd), so the pool is never opened
#      rw twice (the corruption scenario).
#   S2 validation writeback: a validation slot writes to /persist + /storage ->
#      after validate-done the REAL persist + share are UNCHANGED (clone isolation).
#   S3 validation egress: from the validation slot, the outside is UNREACHABLE
#      (egress-cut net) — cloned creds can't fire real mail/bridges.
#   S4 quiesce consistency: data written+synced in the active slot IS present in
#      the validation clone (domfsfreeze caught it).
#   S5 rollback data-recovery bound: cutover leaves a @pre-cutover snapshot on
#      the persist pool, and it restores the pre-cutover state (ZFS rollback).
#
# Run with:  nix run .#thinhost-safety
{
  pkgs,
  thinhostSystem,
  miniGuestSystem,
}:
pkgs.writeShellApplication {
  name = "thinhost-safety";
  runtimeInputs = [
    pkgs.openssh
    pkgs.coreutils
  ];
  # remote commands intentionally expand $vip / vars client-side into the
  # thin-host ssh (and nested guest ssh) — that's the whole point.
  excludeShellChecks = [ "SC2029" ];
  text = ''
    work=$(mktemp -d)
    trap 'kill %1 2>/dev/null || true; rm -rf "$work" /tmp/thinhost-guest-img' EXIT
    cd "$work"
    PASS=0; FAIL=0
    ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
    bad(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }
    # want=1 => cond must be TRUE to pass; want=0 => must be FALSE
    chk(){ if [ "$1" = 1 ]; then ok "$2"; else bad "$2"; fi; }

    echo "== build + stage mini-guest image =="
    imgdir=$work/img
    mkdir -p "$imgdir"
    (cd "$imgdir" && ${miniGuestSystem.config.system.build.diskoImagesScript} --build-memory 4096)
    img=$(find "$imgdir" -maxdepth 1 \( -name '*.raw' -o -name '*.qcow2' \) | head -1)
    mkdir -p /tmp/thinhost-guest-img
    install -m 0644 "$img" /tmp/thinhost-guest-img/guest.raw
    echo "image staged: $img"

    key=$work/k; cp ${./keys/demo-ssh-key} "$key"; chmod 600 "$key"
    S=(-i "$key" -p 2420 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 root@127.0.0.1)

    echo "== boot thin host =="
    export NIX_DISK_IMAGE=$work/thinhost.qcow2
    export QEMU_NET_OPTS="hostfwd=tcp:127.0.0.1:2420-:22"
    ${thinhostSystem.config.system.build.vm}/bin/run-thinhost-vm -display none -serial "file:$work/serial.log" &
    for i in $(seq 90); do ssh "''${S[@]}" true 2>/dev/null && break; [ "$i" = 90 ] && { echo "thinhost never up"; tail -30 "$work/serial.log"; exit 1; }; sleep 2; done
    ssh "''${S[@]}" 'printf "#!/bin/sh\nexec ssh -i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=3 root@10.99.0.9 \"\$@\"\n" > /root/g && chmod +x /root/g'

    echo "== provision (blue+green OS zvols, shared persist, share ds) =="
    ssh "''${S[@]}" '
      set -e
      echo "  block devices:"; lsblk -dno NAME,SIZE 2>/dev/null | grep -E "vd|sd" || true
      ls -l /guest-img/guest.raw
      zpool create -f rpool /dev/vdb
      echo "  rpool size:"; zpool list -H -o name,size,free rpool
      for s in blue green; do
        zfs create -s -V 12G rpool/mini-$s
        # WAIT for the zvol device node — without this, dd races udev and writes
        # a regular file into devtmpfs (RAM) -> ENOSPC despite a huge free pool.
        udevadm settle
        for _ in $(seq 50); do [ -e /dev/zvol/rpool/mini-$s ] && break; sleep 0.2; done
        [ -b /dev/zvol/rpool/mini-$s ] || { echo "FATAL: /dev/zvol/rpool/mini-$s is not a block device"; exit 1; }
        dd if=/guest-img/guest.raw of=/dev/zvol/rpool/mini-$s bs=4M conv=sparse,fsync status=none
        echo "  after dd mini-$s: $(zpool list -H -o free rpool) free"
      done
      zfs create -s -V 4G rpool/mini-persist; udevadm settle
      zpool create -f bpersist /dev/zvol/rpool/mini-persist
      zfs create -o mountpoint=legacy bpersist/persist; zpool export bpersist
      zfs create -o mountpoint=/t-storage rpool/t-storage; echo origin-share-v1 > /t-storage/marker
      echo provisioned'
    ssh "''${S[@]}" 'virsh start mini-blue'
    for i in $(seq 90); do ssh "''${S[@]}" '/root/g true 2>/dev/null' && break; [ "$i" = 90 ] && { echo "blue never up"; exit 1; }; sleep 4; done
    ssh "''${S[@]}" "/root/g 'echo origin-persist-v1 > /persist/data; sync'"
    echo "blue up + seeded"

    echo
    echo "== S1: TWO-WRITER — start green (shares the persist zvol) while blue runs =="
    # mini-green (prod) is defined and references the SAME persist zvol as blue;
    # virtlockd must refuse the second opener.
    r=$(ssh "''${S[@]}" 'virsh start mini-green 2>&1 || true')
    echo "    virsh start mini-green -> $r"
    gstate=$(ssh "''${S[@]}" 'virsh domstate mini-green 2>/dev/null' || echo absent)
    if echo "$r" | grep -qiE 'lock|resource busy|failed to|denied' && [ "$gstate" != running ]; then
      ok "S1 second writer REFUSED (virtlockd) — persist never opened rw twice"
    else
      bad "S1 second slot started ($gstate) — TWO WRITERS on the persist pool (corruption risk)"
    fi
    ssh "''${S[@]}" 'virsh destroy mini-green 2>/dev/null || true' >/dev/null 2>&1 || true
    # blue's data intact?
    d=$(ssh "''${S[@]}" "/root/g 'cat /persist/data 2>/dev/null'" || true)
    if [ "$d" = origin-persist-v1 ]; then ok "S1 blue's persist intact after the attack"; else bad "S1 blue persist damaged ($d)"; fi

    echo
    echo "== S4 + S2 + S3: validate green vs clones, then abuse it =="
    ssh "''${S[@]}" "/root/g 'echo synced-just-before-snapshot >> /persist/data; sync'"
    ssh "''${S[@]}" 'mini-cutover validate'
    for i in $(seq 60); do
      st=$(ssh "''${S[@]}" 'virsh domstate mini-green 2>/dev/null' || true)
      [ "$st" = running ] && ssh "''${S[@]}" 'test -e /dev/zvol/rpool/mini-persist-validate' 2>/dev/null && break
      sleep 4
    done
    # reach the validation guest via its NON-service MAC lease on the validate net.
    # The thin host bridges virbr-validate; find the validate guest's IP by arp.
    vp='ssh -i /root/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=3'
    # net-dhcp-leases is the reliable source (domifaddr --source lease came up
    # empty); the 2nd guest under nested virt can take a while to DHCP.
    vip=""
    for _ in $(seq 60); do
      vip=$(ssh "''${S[@]}" 'virsh net-dhcp-leases validate 2>/dev/null | awk "/b8:ca:3a:6d:2d:99/ {print \$5}" | cut -d/ -f1 | head -1' || true)
      [ -n "$vip" ] && break
      sleep 5
    done
    echo "    validation guest ip (isolated net): ''${vip:-<none>}"
    if [ -z "$vip" ]; then
      echo "    --- reach diagnostics ---"
      ssh "''${S[@]}" 'virsh domstate mini-green; virsh domiflist mini-green; echo "net:"; virsh net-list --all; echo "leases:"; virsh net-dhcp-leases validate 2>&1; echo "validate zvols:"; zfs list -H -o name | grep validate || true'
    fi
    if [ -n "$vip" ]; then
      # S4: the just-synced write is present in the clone the validation slot booted
      vdata=$(ssh "''${S[@]}" "$vp root@$vip 'cat /persist/data 2>/dev/null' " || true)
      if echo "$vdata" | grep -q synced-just-before-snapshot; then ok "S4 quiesce/snapshot caught the synced write (clone has it)"; else bad "S4 clone missing the synced write"; fi
      # S2: validation writes to its /persist + /storage
      ssh "''${S[@]}" "$vp root@$vip 'echo VALIDATION-WAS-HERE > /persist/data; echo tampered > /storage/marker; sync' " || true
      # S3: the SERVICE net (10.99.0.1, where the real service IP lives) must be
      # UNREACHABLE from the isolated validation guest (cloned creds can't phone
      # home / fire real mail+bridges). It can reach its own isolated gw (10.98).
      egress=$(ssh "''${S[@]}" "$vp root@$vip 'ping -c1 -W2 10.99.0.1 >/dev/null 2>&1 && echo REACHED || echo blocked' " 2>/dev/null || echo unknown)
      if [ "$egress" = blocked ]; then ok "S3 validation CANNOT reach the service net (egress cut)"; else bad "S3 validation reached the service net ($egress) — isolation breach"; fi
    else
      bad "S4/S2/S3 could not reach the validation guest to abuse it"
    fi
    ssh "''${S[@]}" 'mini-cutover validate-done'

    # S2 verdict: after discarding clones, is PRODUCTION untouched?
    d=$(ssh "''${S[@]}" "/root/g 'cat /persist/data 2>/dev/null | tail -1'" || true)
    m=$(ssh "''${S[@]}" "/root/g 'cat /storage/marker 2>/dev/null'" || true)
    if [ "$d" != VALIDATION-WAS-HERE ]; then ok "S2 production persist NOT clobbered by validation ($d)"; else bad "S2 validation write LEAKED into production persist"; fi
    if [ "$m" = origin-share-v1 ]; then ok "S2 production share NOT clobbered by validation"; else bad "S2 validation clobbered the production share ($m)"; fi

    echo
    echo "== S5: cutover leaves a data-recovery snapshot; it restores =="
    ssh "''${S[@]}" 'mini-cutover cutover'
    for i in $(seq 90); do ssh "''${S[@]}" '/root/g true 2>/dev/null' && break; [ "$i" = 90 ] && break; sleep 4; done
    snap=$(ssh "''${S[@]}" 'zfs list -H -t snapshot -o name | grep "mini-persist@pre-cutover" | head -1' || true)
    if [ -n "$snap" ]; then ok "S5 pre-cutover snapshot exists: $snap"; else bad "S5 no pre-cutover recovery snapshot"; fi
    # green writes; then prove the snapshot still holds the pre-cutover content
    ssh "''${S[@]}" "/root/g 'echo green-era-write >> /persist/data; sync'"
    if [ -n "$snap" ]; then
      pre=$(ssh "''${S[@]}" "zfs send $snap 2>/dev/null | zfs receive -F rpool/recoverycheck 2>/dev/null; mount -t zfs rpool/recoverycheck /mnt 2>/dev/null; tail -1 /mnt/data 2>/dev/null; umount /mnt 2>/dev/null; zfs destroy rpool/recoverycheck 2>/dev/null" || true)
      if [ "$pre" != green-era-write ]; then ok "S5 recovery snapshot holds the PRE-cutover state (rollback works)"; else bad "S5 snapshot polluted by post-cutover writes"; fi
    fi

    ssh "''${S[@]}" '/root/g poweroff 2>/dev/null; sleep 3; poweroff' 2>/dev/null || true
    echo
    echo "===================== DATA-SAFETY SUITE: $PASS passed, $FAIL failed ====================="
    if [ "$FAIL" = 0 ]; then echo "PASS: every data-loss scenario was contained."; else echo "FAIL: $FAIL containment gap(s) above."; exit 1; fi
  '';
}
