# beefcake-cutover — the blue/green tool (Phase 4), parameterized so the nested
# integration test runs THE SAME script production ships (test-what-you-ship).
# Ports the proven demo flow (quiesce -> snapshot -> clone -> validate on the
# isolated net -> cutover -> rollback) onto libvirt + the real datasets.
#
# Phase-4 persist architecture: the guests' /persist lives on a SHARED zvol
# (its own pool) attached as vdb to exactly ONE slot — production slot XMLs
# reference the real zvol (this tool never runs two prod slots at once);
# validation boots a CLONE of it (plus clones of the share datasets), so a
# validation guest has full identity+state on an egress-cut network and its
# writes are discarded.
{
  pkgs,
  toolName ? "beefcake-cutover",
  slotPrefix, # e.g. "beefcake" -> domains beefcake-blue / beefcake-green
  # [{ dataset; validateMountpoint; }] — clones INHERIT the origin's mountpoint,
  # which would collide with the live mount; each clone gets an explicit one.
  shareDatasets,
  persistZvolDataset, # the persist zvol DATASET, e.g. "rpool/beefcake-persist"
  greenProdXML,
  greenValidateXML,
  markerPath ? "/persist/beefcake-active-slot",
}:
pkgs.writeShellApplication {
  name = toolName;
  runtimeInputs = [
    pkgs.libvirt
    pkgs.zfs
    pkgs.gnugrep
    pkgs.coreutils
  ];
  text = ''
    set -euo pipefail
    MARKER=${markerPath}
    PREFIX=${slotPrefix}
    PERSIST=${persistZvolDataset}
    DS=(${toString (map (d: d.dataset) shareDatasets)})
    DSMNT=(${toString (map (d: d.validateMountpoint) shareDatasets)})
    active() { cat "$MARKER" 2>/dev/null || echo blue; }
    other() { [ "$(active)" = blue ] && echo green || echo blue; }

    cmd="''${1:-status}"
    case "$cmd" in
      status)
        echo "active slot: $(active)"
        virsh list --all || true
        ;;
      validate)
        # Boot green against CLONES (shares + persist) on the isolated net.
        # QUIESCE the active slot first (sqlite WAL / fsync — DD6) so clones
        # are consistent; thaw immediately after snapshotting.
        echo "== quiescing $(active) + snapshotting shares + persist =="
        virsh domfsfreeze "$PREFIX-$(active)" || true
        for i in "''${!DS[@]}"; do
          d="''${DS[$i]}"; m="''${DSMNT[$i]}"
          zfs destroy -r "$d-validate" 2>/dev/null || true
          zfs destroy "$d@validate" 2>/dev/null || true
          zfs snapshot "$d@validate"
          zfs clone -o mountpoint="$m" "$d@validate" "$d-validate"
        done
        zfs destroy -r "$PERSIST-validate" 2>/dev/null || true
        zfs destroy "$PERSIST@validate" 2>/dev/null || true
        zfs snapshot "$PERSIST@validate"
        zfs clone "$PERSIST@validate" "$PERSIST-validate"
        virsh domfsthaw "$PREFIX-$(active)" || true
        echo "== booting green against clones (isolated net, egress-cut) =="
        virsh define ${greenValidateXML}
        virsh start "$PREFIX-green"
        echo "green validating; check it, then: ${toolName} validate-done"
        ;;
      validate-done)
        virsh destroy "$PREFIX-green" 2>/dev/null || true
        virsh undefine "$PREFIX-green" --nvram 2>/dev/null || true
        for d in "''${DS[@]}"; do
          zfs destroy -r "$d-validate" 2>/dev/null || true
          zfs destroy "$d@validate" 2>/dev/null || true
        done
        zfs destroy -r "$PERSIST-validate" 2>/dev/null || true
        zfs destroy "$PERSIST@validate" 2>/dev/null || true
        echo "validation clones discarded; production untouched"
        ;;
      cutover)
        target=green
        [ "$(active)" = green ] && target=blue
        echo "== pre-cutover snapshots (rollback bound) =="
        for d in "''${DS[@]}"; do zfs snapshot "$d@pre-cutover-$target" 2>/dev/null || true; done
        zfs snapshot "$PERSIST@pre-cutover-$target" 2>/dev/null || true
        echo "== stop $(active); start $target on the REAL persist + shares + service MAC =="
        virsh shutdown "$PREFIX-$(active)" || true
        for _ in $(seq 90); do
          virsh domstate "$PREFIX-$(active)" 2>/dev/null | grep -qx "shut off" && break
          sleep 2
        done
        virsh domstate "$PREFIX-$(active)" 2>/dev/null | grep -qx "shut off" || {
          echo "ABORT: $(active) did not shut down cleanly; NOT starting $target (persist single-writer)"; exit 1; }
        if [ "$target" = green ]; then virsh define ${greenProdXML}; fi
        virsh start "$PREFIX-$target"
        echo "$target" > "$MARKER" 2>/dev/null || true
        echo "cutover to $target done; verify, then '${toolName} rollback' if needed"
        ;;
      rollback)
        prev=$(other)
        virsh shutdown "$PREFIX-$(active)" || true
        for _ in $(seq 90); do
          virsh domstate "$PREFIX-$(active)" 2>/dev/null | grep -qx "shut off" && break
          sleep 2
        done
        virsh domstate "$PREFIX-$(active)" 2>/dev/null | grep -qx "shut off" || {
          echo "ABORT: $(active) did not shut down; NOT starting $prev"; exit 1; }
        virsh start "$PREFIX-$prev"
        echo "$prev" > "$MARKER" 2>/dev/null || true
        echo "rolled back to $prev"
        ;;
      *) echo "usage: ${toolName} status|validate|validate-done|cutover|rollback"; exit 1 ;;
    esac
  '';
}
