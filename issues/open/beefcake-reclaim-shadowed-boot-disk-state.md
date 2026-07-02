# beefcake: reclaim ~89G of shadowed migration originals on the boot disk

**Labels**: beefcake, storage, maintenance
**Related**: `issues/closed/beefcake-relocate-state-to-pool.md`,
`lib/doc/beefcake-impermanence-blue-green.md` (Phase 0)

The 2026-06-29 `migrate-state.sh` run relocated `/var/lib/containers` and
`/var/lib/private` onto zstorage by mounting datasets OVER the originals —
deliberately, as an instant-rollback safety net. The originals still occupy
the ext4 boot disk underneath the mounts: `df /` reports 158G used while
`du -x /` sees only ~69G → **~89G shadowed and reclaimable** (plus any
remaining `*.old` trees).

Preconditions:
- zstorage resilver complete and pool ONLINE (was ~79% w/ ~9h ETA at the
  2026-07-01 audit — likely done, verify `zpool status`).
- A few days of confidence in the migrated datasets (they've been serving
  production since 2026-06-29; the box has NOT rebooted since — a clean
  reboot first would prove the ZFS-native mounts come up in the right order
  before deleting the fallback).

Sketch (maintenance window):
1. `zpool status` clean; recent snapshots exist on `zstorage/containers` +
   `zstorage/varlib-private`.
2. Reboot beefcake (also validates mount ordering + flushes the June state).
3. Reveal the shadowed dirs without unmounting production state:
   `mkdir /mnt/rootfs && mount --bind / /mnt/rootfs`, then delete
   `/mnt/rootfs/var/lib/containers`, `/mnt/rootfs/var/lib/private`
   contents (and any `*.old`).
4. Confirm `df /` drops to ~69G; update the disk-alerts thresholds if any
   assumed the old usage.

Frees the headroom the boot spinner needs until the SSD-mirror/impermanence
work (PR #698 phases 2–3) retires it entirely.
