# Mail stack robustness — long-term plan

**Labels**: mail, beefcake, pebble, reliability
**Related**: stalwart-0.16-upgrade (closed), stalwart-kanidm-oidc

The 0.16 migration + Kanidm SSO + PROXY relay + Matrix notifications all
landed and are live-verified. This tracks hardening the result from
"works" to "robust", in priority order. Context for any agent picking
this up: the stack is stalwart 0.16.8 on beefcake (custom module, DB
reconciled by a declarative `stalwart-cli apply` plan), fronted by an
HAProxy PROXY-protocol relay on pebble with a queueing postfix fallback,
authenticating webmail (bulwark) via Kanidm OIDC.

## Tier 1 — config-drift & silent-failure risks (do first)

- [ ] **Codify the trusted-domain SpamRule.** `LYTEDEV_TRUSTED_DOMAIN`
      (passes DMARC-verified `*.lyte.dev` straight to inbox, score −7) was
      applied **live via stalwart-cli only** — it is NOT in
      `beefcake/stalwart.nix` and will silently vanish on any DB rebuild
      (migration replay, disaster restore). Needs a module mechanism:
      SpamRules can't use the plan's destroy-all+create pattern (it would
      nuke all 66 built-in rules), so add an **ensure-by-name** apply step
      (like the OIDC directory's ensure-by-description), then declare the
      rule. Same mechanism should own any future custom spam rules.
- [ ] **Audit for other live-only changes.** Sweep what was applied
      imperatively during the migration vs. what's in the plan. Known
      drift beyond the SpamRule: none confirmed, but the
      reindex/quota/tracer were one-shots or already codified — verify.
- [ ] **Alert when the HAProxy fallback activates.** Today an outage
      silently fails over to pebble's queue; you only notice if you check.
      Wire an alert (beefcake down / pebble queue non-empty) into the
      existing OpenObserve/Prometheus on beefcake — but the alerter must
      not itself depend on beefcake being up (run the check from pebble or
      an external probe).
- [ ] **Alert on stalwart down + queue backlog + cert expiry.** Mail
      delivery has no human-facing signal today. Minimum: stalwart.service
      failed, stalwart MTA queue depth growing, TLS cert <14d to expiry.
- [ ] **Monitor the notify daemon itself.** `jmap-matrix-notify` is a
      single unstaffed daemon; if it dies or its EventSource silently
      stalls, you get no mail pings and no warning. Add a liveness signal
      (heartbeat, or alert on "no events processed in N hours" — though
      quiet inboxes make that noisy; prefer a daemon-emitted heartbeat).

## Tier 2 — make the notify daemon's auth proper

- [ ] **Dedicated Kanidm service account for jmap-matrix-notify.**
      Currently borrows the `bulwark-webmail` public client with a rolling
      refresh token seeded interactively (`get-token.sh --save-refresh`).
      Works indefinitely in steady state, BUT goes stale if the daemon is
      down longer than Kanidm's `refreshTokenExpiry` (~30d), requiring a
      manual re-seed. A Kanidm **service account + long-lived API token**
      (no rolling, no expiry window) is the correct "machine identity"
      model — declarative via a kanidm migration entry + sops token, and
      removes the only manual-bootstrap step in the stack. (This was the
      "surely it needs to be an OAuth app?" instinct — it already is one,
      this just makes it the right kind.)

## Tier 3 — disaster recovery & availability

- [ ] **Test the restic restore path.** restic backs up
      `/storage/stalwart` (verified the *backups run*), but a restore has
      never been exercised. Do a restore-to-scratch drill and confirm a
      RocksDB copy opens cleanly — an untested backup is a hope, not a
      plan. (0.16 is RocksDB; confirm restic captures a consistent copy or
      add a pre-backup checkpoint/snapshot step.)
- [ ] **Decide on inbound availability during a beefcake outage.** Today:
      pebble's queue holds ≤5 days (good — no loss), but there is **no
      read access** to existing mail while beefcake is down (webmail + JMAP
      both live there). Options: accept it (document the SLA), or a warm
      secondary. Likely "accept + document" given the cost of HA mail.
- [ ] **Cert-renewal robustness.** stalwart's TLS cert is copied from
      Caddy and only re-read into the DB when `stalwart-apply` runs (on
      deploy). `copy-stalwart-certificates-from-caddy` now restarts
      stalwart-apply on cert change — verify this actually fires across a
      real Caddy renewal (~60d cycle), since it's never been observed end
      to end.

## Tier 4 — upstream & cleanup debt

- [ ] **kanidm#4387**: when the upstream SCIM-migration whitelist fix
      merges, bump `trunkRev` in `packages/kanidm/package.nix` past it and
      drop `0001-scim-migration-allow-oauth2-required-attrs.patch` (verify
      the merged whitelist covers the strict-redirect / localhost-redirect
      / insecure-pkce attrs our patch adds; keep a slim patch if not).
- [ ] **valerie's Kanidm account.** Her mail access still assumes the old
      path; under OIDC-primary auth she needs a Kanidm account + bulwark,
      or her clients break. Confirm what she actually uses first.
- [ ] **Retire migration leftovers** (~2 weeks stable): delete the ZFS
      snapshot `zstorage/storage@pre-stalwart-0_16-20260610-101733`, the
      legacy `/storage/stalwart/{db,data}` dirs, and
      `/root/stalwart-migration/` (contains password hashes + private keys).
- [ ] **Drop the internal bulwark OAuthClient** from the plan once Kanidm
      SSO is fully trusted (kept as a fallback during cutover).

## Tier 5 — productize the ad-hoc tooling

- [ ] **`mailctl` proper.** The JMAP bulk-ops + token scripts live in
      `/tmp/mailctl` and `beefcake/jmap-matrix-notify/get-token.sh`. If
      bulk folder management / token minting becomes recurring, fold them
      into a real package in the flake with subcommands (token, folders,
      archive-where, purge-folder).
