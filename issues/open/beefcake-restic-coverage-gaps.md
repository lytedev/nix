# beefcake: restic coverage gaps — headscale DB is not backed up

**Labels**: beefcake, backups, data-integrity
**Related**: `lib/doc/beefcake-impermanence-blue-green.md` (Phase 0), 2026-07-01 state audit

The restic jobs (`packages/hosts/beefcake/restic.nix` + per-module
`services.restic.commonPaths` appends) miss several stateful directories.
Found during the impermanence state audit; these live as plain dirs on the
non-redundant ext4 boot spinner, so they have neither pool redundancy NOR
backups today.

## Decisions (Daniel, 2026-07-01) — fixes in PR #700

**Added to restic (PR #700):**
- **`/var/lib/headscale`** — the sqlite DB holding every tailnet node
  registration + preauth keys; losing it means re-registering every device.
  The urgent one.
- **`/var/lib/hearth`** — "for sure should be backed up" (was flagged: dir
  declared but absent from the aggregated restic set).
- **`/var/lib/unifi`** — keep; live-mongodb copy is crash-consistent only.
  Follow-up (Daniel, UI action): enable the controller's scheduled
  autobackup so proper `.unf` dumps land under `data/backup/` (picked up by
  the same restic path once enabled).

**Deliberately excluded (confirmed 2026-07-01):**
- `/var/lib/caddy` — ACME state; re-issuable, little reason to keep.
- `/var/lib/clickhouse` — plausible analytics only; acceptable loss.

## Still open

- `/var/lib/containers` — podman images are rebuildable, but containers are
  per-service: audit each for volume-backed state inside the graph root,
  then decide per service.
- `/var/lib/forgejo-github-mirror`, `/var/lib/meshtasticd`,
  `/var/lib/jmap-matrix-notify` — small/cheap; sweep into a follow-up
  alongside the containers audit.

Redis (nextcloud remnant) and postgres live-datadir are intentionally not
listed: postgres is covered via nightly `pg_dumpall` to
`/storage/postgres-backups`.

Note: the impermanence work (PR #698 design) will force an explicit persist
list for all of these anyway — but the headscale gap should NOT wait for
that project.
