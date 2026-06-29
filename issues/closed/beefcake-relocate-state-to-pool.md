> **COMPLETED 2026-06-29** — executed imperatively via `/root/migrate-state.sh` using **ZFS-native mountpoints** (mountpoint=/var/lib/..., like /storage), NOT the legacy fileSystems approach drafted below. /home trimmed 73G→1.9G (rescue at /storage/daniel/rescue); /var/lib/containers + /var/lib/private now on zstorage with auto-snapshots; originals shadowed under the mounts (reclaim pending). Kept for reference.

# Relocate beefcake stateful data off the single-disk boot drive onto zstorage

**Labels**: beefcake, storage, data-integrity
**Related**: PR for `hardware.nix` fileSystems entries; disk-status work (sde replacement, SSD boot mirror #4)

## Why

Root (`/`) lives on a single, non-redundant ext4 boot disk (`sdj`, a 10K SAS
spinner). Three large trees never moved to the pool, so they have **zero
redundancy** and they're why root sits at 224G/86%:

- `/home` — 73G, but ~99% disposable cruft (see below)
- `/var/lib/containers` — 42G podman overlay store
- `/var/lib/private` — 29G systemd DynamicUser state (tuwunel, plausible,
  gitea-runner, factorio, garage, soju, tempo, otel-collector; n8n now disabled)

Everything else already lives on `zstorage/storage` (`/storage`). Moving these
onto the pool gets them triple-parity redundancy + auto-snapshots, and shrinks
root enough to fit the planned 240GB SSD boot mirror.

## Pre-requisites

- **`sde→sdk` resilver complete** (`zpool status zstorage` shows no resilver).
  Do not run heavy rsync during a rebuild.
- A fresh `zstorage/storage` snapshot as a savepoint is cheap insurance.
- All steps are **copy → verify → swap**; originals are renamed `.old` and kept
  until verified, so rollback is always "remount the old path".

## Part A — /home: rescue then wipe (no relocation needed)

`/home` is entirely `/home/daniel` (others are empty). 60G is rootless podman
images (`~/.local/share/containers`), the rest is caches/toolchains/ISOs/game
tarballs. **Rescue this short list first, then wipe the cruft:**

1. **`/home/daniel/code/nix` — 8 UNPUSHED commits.** Decide: push them, or
   confirm superseded. DO NOT wipe until resolved.
   `git -C /home/daniel/code/nix push` (or cherry-pick what's wanted).
2. Copy key material somewhere durable (e.g. `/storage/daniel/rescue/`):
   - `/home/daniel/.home/.ssh/id_ed25519{,.pub}`
   - `/home/daniel/.home/old-beefcake-backup-stuff/{cache-priv-key.pem,cache-pub-key.pem,old-beefcake-ssh-keys/,rootstuff/}`
3. Confirm `code/evermmore` (clean) and `code/LinuxGSM` (upstream-cloneable).
4. Wipe the rest: `~/.home/.local/share/containers`, `~/.home/.cache`,
   `~/.cache`, `~/.home/.rustup`, `~/.home/.cargo`, the Arch ISO, `hearth-*.tar.gz`,
   `~/.home/.rancher`, the game tarballs in `old-beefcake-backup-stuff`.

Result: `/home` drops from 73G to a few hundred MB → stays on root (fine once
root is the SSD mirror); no dataset required.

## Part B — /var/lib/containers (podman overlay store, ~42G)

Overlay-on-ZFS is supported on this host (OpenZFS 2.4.2, kernel 6.18). Keep the
overlay driver; just relocate the store onto a dataset mounted at the same path.

```bash
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=false zstorage/containers
mkdir -p /mnt/migrate/containers && mount -t zfs zstorage/containers /mnt/migrate/containers
rsync -aHAX --info=progress2 /var/lib/containers/ /mnt/migrate/containers/   # warm copy (services up)
systemctl stop podman.socket podman 'podman-*.service'                       # quiesce
rsync -aHAX --delete /var/lib/containers/ /mnt/migrate/containers/           # final delta
umount /mnt/migrate/containers
mv /var/lib/containers /var/lib/containers.old
mkdir /var/lib/containers && mount -t zfs zstorage/containers /var/lib/containers
systemctl start podman.socket && systemctl start <oci-containers>            # bring back up
# verify: podman images / podman ps -a / each container healthy
```

## Part C — /var/lib/private (DynamicUser state, ~29G)  ← highest risk

Same pattern; the mountpoint must be `0700 root:root`. Tuwunel (Matrix) is here,
so Matrix is briefly down (disk alerts queue, no loss).

```bash
zfs create -o mountpoint=legacy zstorage/varlib-private
mkdir -p /mnt/migrate/private && mount -t zfs zstorage/varlib-private /mnt/migrate/private
rsync -aHAX --info=progress2 /var/lib/private/ /mnt/migrate/private/         # warm copy
# stop every DynamicUser service writing here:
systemctl stop tuwunel plausible gitea-runner factorio-server@* garage soju tempo opentelemetry-collector
rsync -aHAX --delete /var/lib/private/ /mnt/migrate/private/                 # final delta
chmod 700 /mnt/migrate/private && chown root:root /mnt/migrate/private
umount /mnt/migrate/private
mv /var/lib/private /var/lib/private.old
mkdir -m 700 /var/lib/private && mount -t zfs zstorage/varlib-private /var/lib/private
systemctl start tuwunel plausible gitea-runner garage soju tempo opentelemetry-collector
# verify each; confirm Matrix federation + login work
```

## Part D — Persist + finalize

1. Deploy the `hardware.nix` change (adds the two `fileSystems` zfs mounts) so
   the mounts survive reboot. **Order matters: deploy only AFTER B & C data is in
   place** — otherwise empty datasets mount over live state.
2. Reboot-test (or at least `systemctl daemon-reload` + verify mounts) to prove
   the declarative mounts come up cleanly and in the right order.
3. After a few days' confidence, delete `*.old` and the freed boot-disk space.

## ⚠️ Deploy coordination

The finalize deploy (Part D) reverts anything not committed. beefcake currently
runs a **dirty** tree with uncommitted `dns-primary.nix` + `router.nix` edits
(the live LAN-DNS `:53` hairpin fix). Those must be committed/landed first, or
included in the deployed ref, or the deploy regresses DNS/mail. Resolve before
deploying.

## Rollback

Before `*.old` is deleted: `umount` the dataset, `mv X.old X`, restart services.
Data integrity is preserved throughout because nothing is deleted until verified.
