# Blue/green (or sandbox) deploys for server-type machines

Automatic blue/green deployments for server-type machines — and/or a sandbox
environment that mirrors production closely enough to validate a deploy before
it touches the real host.

**Labels**: infra, deploy, reliability

## Motivation

Server hosts (especially `beefcake`) are deployed with a live `switch`, which is
all-or-nothing against production: a bad config or a version skew takes effect
immediately, and recovery is manual and risky.

The 2026-06-28 incident made this concrete. A deploy from a stale workspace
silently **downgraded** beefcake's nixpkgs (2026-06-23 → 2026-05-31). The live
switch:

- forced a systemd re-exec that **wedged** — mass service stop, SSH connection
  dropped, deploy-rs did a messy rollback that left the host on the *older*
  generation;
- downgraded redis (8.8.0 → 8.6.3), which then **refused to load** the dumps the
  newer redis had written (`Can't handle RDB format version 14`), taking
  immich/paperless down;
- dropped `mautrix-gmessages` entirely (its user/group only exist in the newer
  config).

Email stayed up by luck, not design. Recovery was surgical and manual (restart
units, move redis dumps aside, fix the boot default), and full restoration still
needs a reboot that can't happen until an in-progress ZFS resilver finishes.

The short-term mitigation is the "NEVER deploy a rollback" guidance now in
`AGENTS.md` (check branch nixpkgs vs the host's `/run/current-system` before
every deploy). That's a human/agent discipline, not a guard — this issue tracks
making the system *structurally* safe.

## What we want

- **Validate before production**: build + boot/activate the candidate generation
  somewhere isolated (a green slot, a VM/container mirror, or a staging host)
  and health-check it before cutting over the real service.
- **Catch downgrades/rollbacks automatically**: refuse (or loudly warn) when a
  candidate's nixpkgs/toolchain is older than what the target runs.
- **Safe cutover + instant rollback**: switch traffic/state to the validated
  slot atomically, with a one-step revert that doesn't wedge.
- Prioritize the hosts where a bad deploy hurts most (beefcake: mail, matrix,
  immich, forgejo, DNS, …).

## Open questions

- True blue/green (two full slots + state handoff) vs. a lighter "boot the new
  gen in a throwaway VM and smoke-test it" gate. State-heavy services
  (postgres, redis, ZFS datasets) make full blue/green hard.
- How to mirror enough of production (secrets, data) to make validation
  meaningful without copying everything.
- Relationship to the existing `deploy-rs` magic-rollback (which failed to fully
  recover in the incident).
