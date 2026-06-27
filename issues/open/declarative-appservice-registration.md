# Declarative appservice registration between tuwunel and the mautrix bridges

**Labels**: matrix, beefcake, bridges, declarative-config, reliability
**Related**: mautrix-gmessages (bridge, PR #612/#624)

Make the Matrix appservice registrations (homeserver ↔ bridges) reproducible
from the Nix/sops config instead of the current mix of on-disk random tokens +
manual admin-room registration. This is a **shared-primitive change touching all
bridges + tuwunel**, so it's its own work, separate from any single bridge
feature.

## Current state (the problem)

beefcake runs tuwunel (conduwuit fork) as the homeserver with several mautrix
bridges (discord, slack, gmessages, …). Registration is **not declarative**:

- Each bridge generates **random** `as_token`/`hs_token` on first run and stores
  them in `/var/lib/<bridge>/registration.yaml` — **on disk, not in sops**, not
  in the Nix closure.
- tuwunel has **no static appservice config path** (unlike Synapse's
  `app_service_config_files`). Registrations are entered **by hand** via the
  admin room (`!admin appservices register` + the YAML in a code block) and
  persisted in tuwunel's RocksDB.

Failure modes this creates:

- **State-dir wipe / disaster restore silently breaks auth.** If a bridge's
  `/var/lib/<bridge>` is wiped, it regenerates *new* random tokens that no longer
  match tuwunel's stored registration → `as_token was not accepted` → crash-loop
  → failed deploy + rollback. (Hit exactly this with gmessages 2026-06; worked
  around by pinning `registration.yaml` on disk.)
- **Every new bridge needs a manual admin-room step**, easy to forget and not
  captured anywhere in the repo.
- tuwunel's RocksDB is the only source of truth for what's registered; nothing
  reconciles it against what the bridges expect.

## Goal

Tokens live in **sops**; the bridge config and the tuwunel-side registration both
derive from the **same** secret, and registration is reconciled automatically (no
manual admin-room step, survives rebuilds/restores).

## Approach options (to evaluate)

- [ ] **Stable tokens from sops.** Generate a fixed `as_token`/`hs_token` per
      bridge as sops secrets. Inject into each bridge's
      `appservice.as_token`/`hs_token` (or its config-gen step) AND into a
      deterministically-generated `registration.yaml`, so the on-disk file is no
      longer the source of truth. (gmessages' `init` already *preserves* an
      existing `registration.yaml` — switch it to *write* one from sops.)
- [ ] **Reconcile tuwunel's registrations declaratively.** No static file path
      exists, so investigate:
      - `admin_execute` (runs admin commands at startup) → register each
        appservice YAML on boot. Source says "registering with an existing ID
        replaces the old entry", so it should be idempotent/safe to re-run.
        Cost: embed the registration YAML in tuwunel's config (sops template).
      - A systemd oneshot after `tuwunel.service` that posts the registration via
        the admin room / an admin API path.
      - Re-check upstream tuwunel/conduwuit for a config-file-based appservice
        registration option (didn't exist as of the gmessages work).
- [ ] **Document the manual fallback** in the bridge module(s) regardless, so the
      admin-room command + required token wiring is captured for the next bridge.

## Acceptance

- A bridge's `/var/lib/<bridge>` can be wiped and a `deploy` brings it back
  authenticated with **no manual admin-room step**.
- Adding a new bridge needs only Nix/sops changes, no hand-run registration.
