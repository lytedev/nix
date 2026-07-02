# beefcake: /var/lib/{containers,private} ZFS mounts are invisible to the config

**Labels**: beefcake, nix, reproducibility
**Related**: `issues/closed/beefcake-relocate-state-to-pool.md`,
`lib/doc/beefcake-impermanence-blue-green.md` (Phase 0 / superseded by Phase 1)

`zstorage/containers` → `/var/lib/containers` and `zstorage/varlib-private` →
`/var/lib/private` are ZFS-native mounts (`mountpoint=` property) created
imperatively on 2026-06-29. `hardware.nix:40-44` documents why they are NOT in
`fileSystems` (a legacy-mount entry would conflict with the live native
mounts) — but the result is that a from-scratch rebuild of beefcake would
come up WITHOUT these mounts and silently write container/DynamicUser state
to the boot disk again.

Options:
1. Convert to `mountpoint=legacy` + `fileSystems` entries (one short
   downtime per dataset: stop consumers, `zfs set mountpoint=legacy`,
   mount via config). Fully declarative, standard ordering.
2. Keep ZFS-native and add an assertion/activation check that fails the
   build (or loudly warns) if the datasets/mounts are absent — documents
   intent without the migration.
3. Fold into the impermanence redesign (PR #698 Phase 1): the persist-list
   work re-homes `/var/lib` state explicitly anyway, and its layout
   (datasets + `neededForBoot` + impermanence binds) subsumes this. If
   Phase 1 lands soon, do nothing here beyond tracking.

Recommendation: (3) if the impermanence work proceeds on schedule; fall back
to (1) during the same maintenance window as the shadowed-state reclaim if it
stalls.
