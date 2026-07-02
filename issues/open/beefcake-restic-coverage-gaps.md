# beefcake: restic coverage gaps — headscale DB is not backed up

**Labels**: beefcake, backups, data-integrity
**Related**: `lib/doc/beefcake-impermanence-blue-green.md` (Phase 0), 2026-07-01 state audit

The restic jobs (`packages/hosts/beefcake/restic.nix` + per-module
`services.restic.commonPaths` appends) miss several stateful directories.
Found during the impermanence state audit; these live as plain dirs on the
non-redundant ext4 boot spinner, so they have neither pool redundancy NOR
backups today.

## Definite gap (fix first)

- **`/var/lib/headscale`** — the sqlite DB holding every tailnet node
  registration, preauth keys, DERP state. Losing it means re-registering
  every device on the tailnet. One-line `services.restic.commonPaths`
  append in `headscale.nix`.

## Decide-and-document (each is a judgment call, not obviously a bug)

- `/var/lib/caddy` — ACME account + issued certs. Re-issuable, but losing it
  mid-outage adds rate-limit risk. Cheap to include.
- `/var/lib/clickhouse` — plausible analytics; restic exclusion is
  deliberate (commented out in `clickhouse.nix`). Confirm "acceptable loss"
  is still the intent, or back it up.
- UniFi mongodb (`/var/lib/unifi`) — controller config; losing it means
  re-adopting APs. Alternative: rely on UniFi's own autobackup dir (verify
  it's enabled and that dir is under a covered path).
- `/var/lib/forgejo-github-mirror`, `/var/lib/meshtasticd`,
  `/var/lib/jmap-matrix-notify` — small; probably cheap to include.
- `/var/lib/hearth` — verify: dir is declared for the container but did not
  appear in the aggregated restic path list during the audit.
- `/var/lib/containers` — podman images/volumes; rebuildable, but any
  volume-backed state inside would be silently unprotected. Audit for
  volumes, then decide.

Redis (nextcloud remnant) and postgres live-datadir are intentionally not
listed: postgres is covered via nightly `pg_dumpall` to
`/storage/postgres-backups`.

Note: the impermanence work (PR #698 design) will force an explicit persist
list for all of these anyway — but the headscale gap should NOT wait for
that project.
