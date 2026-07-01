# k8s persistence — storage story + gaps

**Labels**: k8s, k3s, beefcake, storage, backup
**Related**: restic-app-backup-registration, sec-k8s-platform (in-flight PR),
sec-restic (in-flight PR)

## Current state (verified live 2026-07-01)

The cluster **does** have a working persistence story, and it's configured
correctly:

- Default StorageClass **`local-path`** (Rancher local-path-provisioner,
  `rancher.io/local-path`), binding mode `WaitForFirstConsumer`, reclaim
  `Delete`. A PVC "just works" (dynamic provisioning).
- Provisioner config points at **`/storage/k3s/storage`**, which is
  `zstorage/storage` — the **draid3 ZFS pool**, not the boot SSD. So PV data
  lands on the same redundant, disk-failure-resilient storage as everything
  else. (This correctly follows the custom `--data-dir=/storage/k3s`; a common
  footgun is PVs landing on the boot disk — ours don't.)
- `hostPath` is the other option (mount `/storage/<app>` directly) — good for
  adopting existing data dirs (the hearth-style pattern).
- **No PVCs exist yet** — the cluster is stateless today (system pods + a stale
  `echo-server` + a `whoami` example). Single-node, so there's no
  replicated/networked storage — and that's fine: the ZFS pool is the
  durability layer.

## Gaps to close before stateful workloads land

1. **Backup coverage.** `/storage/k3s/storage` is durable but **not in any
    restic path**. When apps move to PVCs, that data is redundant-but-not-
    backed-up. Fold it into restic — ideally via the general mechanism in
    [[restic-app-backup-registration]] rather than another hardcoded path.
2. **Reclaim policy is `Delete`** — deleting a PVC deletes the PV *and its
    data*. Document this footgun; use `Retain` (or hostPath) for anything that
    matters. Consider a non-default StorageClass with `Retain` for stateful
    apps.
3. **No ZFS snapshots of the k3s storage** for point-in-time recovery — cheap
    on the pool, complements restic, and gives crash-consistent PV rollback.

## Notes

The `sec-k8s-platform` PR includes a podman→k8s migration plan
(`lib/doc/podman-to-k8s-migration.md`) that should reference this persistence
model (local-path PVC vs hostPath, storage on `/storage`) as the storage
section. This issue tracks the **gaps** (backup + reclaim + snapshots); the
migration plan tracks *what moves and in what order*.
