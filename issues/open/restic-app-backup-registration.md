# Declarative "back me up" mechanism — connect apps to restic

**Labels**: backup, restic, beefcake, platform, ergonomics
**Related**: k8s-persistence, mail-stack-robustness (Tier 3 restic drill), sec-restic (in-flight PR)

## Problem

Restic's backup set is a **hand-maintained list** in
`packages/hosts/beefcake/restic.nix` (`services.restic.commonPaths` + per-repo
`paths`). Adding a new stateful service means remembering to go edit `restic.nix`
separately from the module that actually owns the data. This is
error-prone and out of sight:

- New services silently ship **unbacked-up** — nothing fails, nothing warns; you
  only find out at restore time. (The k8s local-path PV dir
  `/storage/k3s/storage` is the current example — durable on the ZFS pool, but
  not in any restic path. See [[k8s-persistence]].)
- The app's data location and its backup declaration live in two different
  files, so they drift.
- There's no place to attach **consistency requirements** (a Postgres/RocksDB
  needs a dump or ZFS snapshot for a consistent copy, not a hot file read) — so
  today those are either missing or bolted on ad hoc.

## What we want

A declarative interface so an app **registers its own backup needs colocated
with its module**, and restic aggregates them. Rough shape (name TBD):

```nix
# in some service's module, next to where its state dir is defined
lyte.backup.jobs.immich = {
  paths = [ "/storage/immich" ];
  excludes = [ "/storage/immich/thumbs" ];   # regenerable
  # optional consistency hook — snapshot/dump before restic reads
  preHook = "zfs snapshot zstorage/immich@backup-$(date ...)";
  # optional: which repos / cadence class this belongs to
  tier = "important";   # e.g. important = all 3 repos, bulk = local only
};
```

Then `restic.nix` becomes a **consumer** that folds every registered job into
the actual `services.restic.backups.*` (paths, excludes, and pre/post hooks),
instead of a hardcoded path list. Design questions to settle:

- **Aggregation model.** A `lyte.backup.jobs` attrset (per-app) vs. a simple
  `lyte.backup.paths` list contributed to by many modules. Attrset is richer
  (per-app excludes/hooks/tier); list is simplest. Lean attrset.
- **Tiers / cadence.** Today there are 3 repos (local, rascal, benland) on one
  2×/day timer. Big media (`/storage/immich`, `/storage/family`) is what makes
  runs take >1 day (see sec-restic). The mechanism should let an app pick a
  cadence/repo class so bulk media can go less frequently than small
  fast-changing state.
- **Consistency hooks.** First-class pre/post per job — for DB dumps
  (`pg_dump`), RocksDB/stalwart checkpoints, or a ZFS snapshot-then-back-up-the-
  snapshot pattern (the correct answer for most `/storage/*` datasets since
  they're ZFS-native).
- **Discoverability / safety net.** Bonus: a check (eval assertion or a report)
  that flags `/storage/*` datasets or declared service state dirs that are NOT
  covered by any backup job — so "I forgot to back it up" becomes visible
  instead of silent.

## Why now

The security audit (2026-07) surfaced restic gaps (no retention, no failure
alerting, unbounded growth, single shared passphrase) — the `sec-restic` PR
addresses those. This issue is the **ergonomic/coverage** half: make it hard to
add a service and forget to back it up, and give consistency hooks a home. Best
tackled after `sec-restic` lands so the mechanism is built on the
retention/alerting-fixed baseline.
