# Stalwart 0.15.5 → 0.16.x upgrade plan

**Labels**: service, mail, beefcake, breaking-change
**Related**: bulwark webmail sort bug (needs 0.16.1+ + reindex); webmail
"Not found" dashboard cards (webadmin shipped is 0.16-era, backend is 0.15.5,
endpoints don't match)

## Why this is non-trivial

This is a **major breaking-change upgrade** with significant manual steps
and required downtime. Stalwart's official guide:
<https://github.com/stalwartlabs/stalwart/blob/v0.16.8/UPGRADING/v0_16.md>

What changes:

- **TOML → JSON.** The on-disk config becomes a tiny `config.json` that
  describes only the datastore. Everything else (domains, accounts, DKIM,
  routing, listeners, spam rules, …) lives **inside the database** and is
  reconciled by `stalwart-cli apply <plan.json>`.
- **REST `/api/...` → JMAP.** Anything calling the old admin REST API breaks.
  Our `stalwart-ensure-bulwark-oauth.service` hits `/api/principal` directly
  and **will fail** under 0.16. Has to be rewritten in terms of
  `stalwart-cli` or JMAP `Principal/set`.
- **Account names must be email addresses.** Bare-`daniel` becomes
  `daniel@lyte.dev`. The migration script handles the rename; CalDAV/CardDAV
  URLs change (`/dav/cal/daniel` → `/dav/cal/daniel%40lyte.dev`) and any
  external directory filters need updating.
- **Database wipe on first start.** Settings, directory entries, reports,
  pending tasks, telemetry, spam training samples, and disk quotas are all
  deleted unconditionally. **Mail data (mailboxes, calendars, contacts,
  files, blobs) is NOT touched.**
- **Plain-text submission (587) is no longer added by default.** Need to
  re-add it via the new CLI/UI if any client still uses STARTTLS on 587.
- **Discovery URLs** now strictly use `https://<defaultHostname>/...`.
  Hitting `http://...:8080` for day-to-day admin no longer works.

## Why we're NOT doing it today

1. **nixpkgs is not ready.** PR
   [NixOS/nixpkgs#512341](https://github.com/NixOS/nixpkgs/pull/512341)
   (the 0.15.5 → 0.16.0 bump) is still in **draft** and the tracking issue
   [#511880](https://github.com/NixOS/nixpkgs/issues/511880) calls out that
   the module needs a rework. Maintainer @oddlama said: "merging this will
   break the module and all existing instances. We need to update the module
   alongside." So even a clean package bump leaves us without a working
   module — `services.stalwart.settings = {...}` would generate a TOML
   config that 0.16 doesn't read.
2. **Last deploy wedged.** `switch-to-configuration` hung at 100% CPU for
   15+ min on 2026-06-04 and left us with a half-applied generation. Until
   that's diagnosed I don't want a mail outage on the line if the same
   thing happens.
3. **No test environment.** The upstream guide **strongly recommends** a
   throwaway VM/container running 0.16 first, to (a) learn the new UI/CLI
   and (b) export a `stalwart-cli snapshot` we can replay alongside the
   migration. Worth setting up before the production cut.

## What I'd want in place before doing this

- [ ] **Fresh full backup** of `/storage/stalwart` (15 GB, embedded
      RocksDB). The migration is irreversible without it. Existing restic
      run covers `dataDir`; verify the most recent snapshot completed.
- [ ] **0.16 sandbox.** Either nixpkgs PR merges with a working module, or
      we run stock upstream Docker (`stalwartlabs/stalwart:v0.16`) on a
      different host / container, walk through the WebUI, export
      `snapshot.json` of any custom rules we want to keep.
- [ ] **Custom nix module path decided.** Either wait for nixpkgs, or
      write our own overlay that:
      - bumps `pkgs.stalwart` to 0.16.8 (just hash/tag bump — package
        builds in PR #512341)
      - writes a minimal `/etc/stalwart/config.json` (datastore pointer)
      - drops the systemd unit's `--config=<toml>` arg, points at
        `config.json`
      - adds a oneshot `stalwart-apply` service that runs
        `stalwart-cli apply --file <plan.json>` after the binary is up
      - generates `plan.json` from a Nix expression that mirrors what
        the old TOML settings encoded (listeners, queues, DKIM, etc.)
      - replaces the `stalwart-ensure-bulwark-oauth` curl-to-`/api/principal`
        script with `stalwart-cli` invocations
- [ ] **Migration `export.json` produced.** Run the upstream Python
      script (`migrate_v016.py dump` + `convert`) against the live 0.15.5
      and review the output before the cutover.
- [ ] **STARTTLS 587 decision.** If we want submission on 587 to keep
      working post-upgrade, add the listener explicitly via the plan.
- [ ] **Communications.** Heads-up to anyone using CalDAV/CardDAV/WebDAV
      clients (Apple Calendar, DAVx⁵, Thunderbird) that the path changes.

## Step-by-step (when ready)

Reference: <https://github.com/stalwartlabs/stalwart/blob/v0.16.8/UPGRADING/v0_16.md>

1. **No-downtime prep:** run migration script against live 0.15.5,
   produce `config.json` and `export.json`. Review.
2. **Begin downtime window:** stop `stalwart.service`.
3. **Backup:** `cp -a /storage/stalwart /storage/stalwart.v015-backup`.
4. **Start new binary in recovery mode** from foreground (not under
   systemd):

   ```bash
   sudo -u stalwart-mail env \
     STALWART_RECOVERY_MODE=1 \
     STALWART_RECOVERY_ADMIN=admin:<temp> \
     /nix/store/<new-stalwart>/bin/stalwart \
       --config=/etc/stalwart/config.json
   ```

5. **From a second shell:** `stalwart-cli apply --file export.json`
   (and any test-deployment snapshot).
6. **Stop recovery binary**, update the nix module to use the new
   config path, switch off the `STALWART_RECOVERY_*` env vars (but keep
   `STALWART_RECOVERY_ADMIN` until a permanent admin exists in the new
   UI; then drop it).
7. **`nixos-rebuild switch`** to the new generation with v0.16. Start
   the service normally; verify mail ports come up.
8. **Post-migration tasks (WebUI → Tasks):**
   - Recalculate disk quotas (all accounts).
   - **Index document, type: email** — this is what actually fixes the
     "older mail above newer" bug. Triggers re-indexing of `receivedAt`
     for the legacy import.
9. **Verify:**
   - send/receive a test message end-to-end
   - bulwark logs into the new OAuth (the
     `OAUTH_ALLOW_PRIVATE_ENDPOINTS=true` fix from PR #566 should still
     apply)
   - the admin dashboard's overview/stats cards stop showing "Not found"
   - the inbox sort order shows newest-first
10. **Cleanup:** drop `STALWART_RECOVERY_ADMIN`; consider also deleting
    `/storage/stalwart.v015-backup` once a few good restic snapshots
    of the new layout exist.

## Bulwark OAuth bootstrap (rewrite required)

Current `stalwart-ensure-bulwark-oauth.service` does:

```bash
curl -u "admin:$pw" http://[::1]:38181/api/principal/bulwark-webmail
curl -u "admin:$pw" -X POST -d '<json>' http://[::1]:38181/api/principal
```

Both endpoints are gone in 0.16. Two replacement paths:

- **`stalwart-cli`** — declarative, fits the "apply plan" model:
  the oauth client becomes one entry in the same plan.json.
- **JMAP `Principal/set`** — preserve the existing oneshot shape;
  POST to `/jmap` with an auth token. More code, less idiomatic.

Prefer the first.

## Worst case rollback

If recovery-mode wipe completes but `apply` fails irrecoverably,
restoring `/storage/stalwart.v015-backup` over `/storage/stalwart`
and switching back to the 0.15.5 generation returns the system to
pre-migration state. The 0.16 binary will refuse to start against an
0.15 schema, so the rollback path is: stop service → restore
backup → `nixos-rebuild switch --rollback` (or specific generation).
