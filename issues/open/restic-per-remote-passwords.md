# Per-remote restic backup passphrases

Give each restic destination its own repository passphrase instead of sharing a
single one across all three repos.

**Labels**: beefcake, backups, security
**Related**: `packages/hosts/beefcake/restic.nix`, PR #677 (restic alerting +
retention), disk-alerts.nix (webhook pattern)

## Motivation

All three restic repos — `local` (`/storage/backups/local`), `rascal`
(sftp → rascal over the VPN), and `benland` (sftp → n.benhaney.com) — currently
share the **one** passphrase secret `restic-rascal-passphrase`
(`config.sops.secrets.restic-rascal-passphrase.path`), used both by
`services.restic.backups.*` and by the `backup-canary-read` restore checks. The
in-code TODO already flags this for `benland`:

```
# TODO: benland should have its own passwordfile, should be able to update the repository?
```

A single shared passphrase means:

- One leaked passphrase exposes **every** copy of the backups (local + both
  offsite), defeating the point of geographically separating them.
- It's entangled with the larger immutability concern (a compromised beefcake
  holds the one key that unlocks all three) — see the immutability plan in
  PR #677.

## Why this wasn't done in PR #677

It is **not** a config-only change, so it was deliberately deferred:

- Each repo was **initialised with the shared passphrase**. Simply pointing a
  backup's `passwordFile` at a new secret makes restic unable to unlock the
  existing repo (wrong key), breaking both the backup and the restore-canary.
- Rotating correctly requires live `restic key add` (new passphrase) +
  `restic key remove` (old) against each repo — a runtime credential operation.
- Declaring a `sops.secrets.<new>` that doesn't yet exist in the encrypted file
  fails sops-nix activation, so the secret must be minted first.

## Proposed procedure (per repo — start with `benland`)

1. Mint a fresh passphrase; add it to `secrets/beefcake/secrets.yml` under e.g.
   `restic-benland-passphrase` (`nix develop -c sops secrets/beefcake/secrets.yml`).
2. On beefcake, add the new key to the existing repo and verify it unlocks:
   ```
   restic -r sftp://daniel@n.benhaney.com://storage/backups/beefcake \
     -o sftp.command="ssh daniel@n.benhaney.com -p 10022 -i <benland-ssh-key> -s sftp" \
     key add          # prompts for current (shared) passphrase, then the new one
   ```
   Confirm the new passphrase unlocks the repo (`restic … snapshots`).
3. `restic … key remove <old-key-id>` once the new key is verified.
4. In `restic.nix`, declare `sops.secrets.restic-benland-passphrase` and set
   `benland = defaults // { passwordFile = …restic-benland-passphrase…; }`.
   Update the `benland` branch of `backup-canary-read` to use the same file
   (it currently hardcodes `restic-rascal-passphrase`).
5. Deploy, then confirm a clean `benland` backup + a green restore-canary.
6. Repeat for `rascal` (and `local`) with their own secrets if desired. Do
   **not** change the existing `rascal` passphrase without the same add/verify/
   remove dance.

## Notes / gotchas

- The `backup-canary-read` service restores from all three repos and currently
  passes `restic-rascal-passphrase` for each — it must be updated in lockstep
  with each repo's rotation or the canary will fail (and now page, post-#677).
- Keep the change per-repo and reversible; verify unlock with the new key
  **before** removing the old one so a mistake can't lock you out of a backup.
- Interacts with the immutability plan (PR #677): if a repo later becomes
  append-only / pull-based, key management may move server-side — sequence
  accordingly.
