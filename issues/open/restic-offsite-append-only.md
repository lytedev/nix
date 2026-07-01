# Offsite append-only / immutable restic backups

Make at least one offsite restic repo resistant to a compromised beefcake, so a
break-in (or ransomware, or a buggy prune) can't `forget`/delete/repack the
offsite copy.

**Labels**: beefcake, backups, security
**Related**: `packages/hosts/beefcake/restic.nix`, PR #677 (restic alerting +
retention), `restic-per-remote-passwords.md`

## Motivation

Today beefcake holds every repo's passphrase **and** the SSH keys, and it
**pushes** to all three destinations (`local`, `rascal`, `benland`). So a
compromised beefcake has full read/write/delete on every copy of the backups —
it can `restic forget` + `prune` or overwrite them, defeating the point of
keeping offsite copies. The in-code TODO already calls this out:

```
# TODO: How do I set things up so that a compromised server doesn't have access to
#       my backups so that it can corrupt or ransomware them?
```

The failure-alerting + retention work (PR #677) improves reliability but does
**not** address this threat — a full-access key on beefcake still governs all
three repos.

## Options (strongest → simplest)

1. **Pull-based (strongest).** Invert the flow: `rascal` / `benland` run the
   `restic` client on their own timer and **pull** from beefcake (beefcake
   exposes a read-only source; the offsite host owns the repo it writes to).
   beefcake never holds credentials that can mutate the offsite copy, so a
   beefcake compromise can't reach back and destroy it. Biggest change (moves
   the backup driver offsite, needs the passphrase to live on the offsite host).

2. **`rest-server --append-only` (recommended balance).** Stand up
   [`rest-server`](https://github.com/restic/rest-server) at an offsite host
   run with `--append-only`; point a repo at it. beefcake's key can add data but
   the server refuses deletes/repacks. `rascal` is the natural first target
   (already on the VPN, already our infra). Medium effort: deploy rest-server on
   rascal + switch that repo's `repository` to `rest:https://…`.

3. **restic `--append-only` key on the existing SFTP repo (weakest).** restic's
   append-only enforcement is client-side, so a full-access key on the box still
   bypasses it; only meaningful combined with server-side controls. Not worth
   doing alone.

**Recommendation:** pursue **(2) rest-server --append-only on rascal** first —
best protection-per-effort, and rascal is already trusted infra we control.

## Important interaction with retention (PR #677)

Append-only repos are **incompatible with `forget --prune` run from beefcake**
(prune deletes/repacks). Whichever repo becomes append-only must have its
`pruneOpts` dropped, and retention for it must move to the trusted side:

- `rest-server` supports server-side `prune` (run on the offsite host, which
  holds a full-access key locally), **or**
- in the pull-based model the pulling host runs `forget --prune` itself.

So sequence this with the retention policy: keep beefcake-side prune for
full-access repos, and move prune off-box for any repo we make append-only.

## Acceptance

- At least one offsite repo (start: `rascal`) is append-only from beefcake's
  perspective: verify beefcake **cannot** `restic forget`/`prune`/delete against
  it, but a normal backup still succeeds.
- Retention for that repo runs on the trusted side (server-side or pull-side),
  not from beefcake.
- Restore-canary still passes against it.
