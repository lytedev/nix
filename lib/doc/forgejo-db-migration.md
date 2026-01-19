# Forgejo Database Migration: HDD to SSD

## Background

git.lyte.dev (Forgejo on beefcake) experienced severe performance degradation under load, especially during nix builds. The root cause was the SQLite database living on spinning HDDs (`/storage/forgejo` on the `zstorage` pool).

SQLite's file-level locking combined with slow HDD I/O creates contention during concurrent access to the web interface.

## Solution

Move only the SQLite database to SSD (root filesystem on `zroot`), keeping repositories and LFS data on HDDs where sequential I/O is acceptable.

**New database path:** `/var/lib/forgejo-db/forgejo.db`

## Migration Steps

```bash
# 1. Stop forgejo
sudo systemctl stop forgejo

# 2. Create the directory with correct permissions
sudo systemd-tmpfiles --create

# 3. Copy existing database to SSD
sudo cp /storage/forgejo/forgejo.db /var/lib/forgejo-db/
sudo chown forgejo:forgejo /var/lib/forgejo-db/forgejo.db
sudo chmod 600 /var/lib/forgejo-db/forgejo.db

# 4. Deploy the new config
# from your local machine:
, deploy -s --targets ".#beefcake"
# or on beefcake directly:
sudo nixos-rebuild switch --flake /path/to/nix#beefcake

# 5. Start forgejo and verify
sudo systemctl start forgejo
sudo systemctl status forgejo
curl -I https://git.lyte.dev

# 6. After confirming stability, remove old database
sudo rm /storage/forgejo/forgejo.db
```

## What Changed

In `packages/hosts/beefcake/forgejo.nix`:

1. Set `database.path` to `/var/lib/forgejo-db/forgejo.db`
2. Added tmpfiles rule to create `/var/lib/forgejo-db` with correct ownership
3. Added `/var/lib/forgejo-db` to restic backup paths

## Rollback

If issues occur, revert the config changes and copy the database back:

```bash
sudo systemctl stop forgejo
sudo cp /var/lib/forgejo-db/forgejo.db /storage/forgejo/
sudo chown forgejo:forgejo /storage/forgejo/forgejo.db
# revert config and redeploy
sudo systemctl start forgejo
```

## Future Consideration

If performance issues persist, consider migrating to PostgreSQL (already running on beefcake). Forgejo has built-in migration tooling via `forgejo dump` and restore.
