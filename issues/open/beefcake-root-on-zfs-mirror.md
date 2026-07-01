# beefcake: root-on-ZFS SSD boot mirror

**Labels**: beefcake, storage, boot, redundancy
**Related**: `packages/hosts/beefcake/hardware.nix`, `issues/closed/beefcake-relocate-state-to-pool.md`, `packages/hosts/beefcake/disk-identification.nix`

## Goal

Give beefcake a **redundant boot device**. Today `/` is ext4 on a *single*
Seagate HDD in the rear flex bay (its old mirror partner died). If that disk
dies, beefcake won't boot even though all the *data* (`zstorage`) is triple-parity
safe. Fix: put `/` on a **2-disk ZFS mirror** across the two new Samsung PM863a
SSDs, matching the rest of the host (ZFS everywhere, snapshots, scrub, and the
disk-alerting from #615 already covers SSDs via smartd/ZED).

`/nix` stays on `zstorage/nix` (608G — far too big for 240G SSDs). Only the root
filesystem (~90G) moves to the SSD mirror (`rpool`).

## Disks

| role | by-id | bay | size |
| ---- | ----- | --- | ---- |
| SSD-A (installed, blank) | `ata-SAMSUNG_MZ7LM240HMHQ-00003_S3LKNX0HC03765` (`wwn-0x5002538c404a5a40`) | 12 | 223.6G |
| SSD-B (bought, not yet inserted) | `ata-SAMSUNG_MZ7LM240HMHQ-…` (second unit) | — | 223.6G |
| current boot HDD (live `/`) | `wwn-0x5000c500718be1cf` (serial S0K1VLAN), `/dev/sdf` | 13 | 279G ext4 |

Always reference disks by **by-id / by-partlabel**, never `/dev/sdX` (they
renumber). Locate LEDs don't work on this host — identify by bay+serial with
`disk-bays` (see `disk-identification.nix`).

## Partition + naming scheme (both SSDs identical)

GPT, per SSD:
- part 1 — 1 GiB, type `EF00` (ESP), fat32, fs label `BOOT`, GPT name **`ESP-A`** / **`ESP-B`**
- part 2 — rest, type `BF00` (Solaris root / ZFS), GPT name **`rpool-A`** / **`rpool-B`**

The NixOS config (this PR's `hardware.nix`) hard-codes:
- `/` = `rpool/root` (zfs, `mountpoint=legacy`)
- `/boot` = `/dev/disk/by-partlabel/ESP-A`
- ESP mirror = `boot.loader.systemd-boot.extraInstallCommands` rsyncs `/boot` →
  `by-partlabel/ESP-B` after every bootloader install (skips cleanly while ESP-B
  is absent, i.e. Phase 1).

Boot redundancy relies on each ESP carrying systemd-boot's fallback
`\EFI\BOOT\BOOTX64.EFI`, so firmware can boot either SSD if the other dies.

## Phases

### Phase 0 — Prep (no downtime) — **DONE in this PR**
- `hardware.nix` rewritten for root-on-ZFS (staged; **do not deploy/merge until
  Phase 1** — deploying it before `rpool/root` exists makes beefcake unbootable).
- Evals cleanly (`nix eval …#nixosConfigurations.beefcake…toplevel.drvPath`).
- This issue filed.
- **Next:** Daniel schedules a maintenance window + comms (mail/git/matrix/DNS all
  live on beefcake). Expect one reboot; ~15–30 min.

### Phase 1 — Migrate `/` onto a single-disk `rpool` on SSD-A (downtime window)
Gets beefcake booting from ZFS on the *new* SSD (still non-redundant until P2),
and frees the old HDD as a fallback. Run from `root@192.168.0.9` (LAN):

```bash
SSD_A=/dev/disk/by-id/ata-SAMSUNG_MZ7LM240HMHQ-00003_S3LKNX0HC03765
# 1. Partition SSD-A
sgdisk -Z "$SSD_A"
sgdisk -n1:1M:+1G  -t1:EF00 -c1:ESP-A   "$SSD_A"
sgdisk -n2:0:0     -t2:BF00 -c2:rpool-A "$SSD_A"
udevadm settle
mkfs.vfat -F32 -n BOOT /dev/disk/by-partlabel/ESP-A

# 2. Create rpool + legacy-mounted root (hostid already 541ede55 = matches /etc/hostid)
zpool create -f -o ashift=12 \
  -O compression=zstd -O acltype=posixacl -O xattr=sa -O atime=off \
  -O mountpoint=none rpool /dev/disk/by-partlabel/rpool-A
zfs create -o mountpoint=legacy rpool/root

# 3. Copy the live root (‑x stays on the ext4 fs, so /nix, /boot, /storage,
#    /var/lib/{containers,private} — all separate mounts — are skipped)
mount -t zfs rpool/root /mnt
rsync -aHAXx --info=progress2 --delete / /mnt/

# 4. Install the new generation onto ESP-A + ZFS root via nixos-enter
mount /dev/disk/by-partlabel/ESP-A /mnt/boot   # (mkdir /mnt/boot first if needed)
for d in dev proc sys run; do mount --rbind /$d /mnt/$d; done
mount --rbind /nix /mnt/nix
nixos-enter --root /mnt -- nixos-rebuild boot \
  --flake "git+https://git.lyte.dev/lytedev/nix?ref=<this-branch>#beefcake"
```

Then reboot. Verify: `findmnt /` → `rpool/root` zfs; `zpool status rpool` →
single-disk ONLINE; all services up (`systemctl --failed` empty). The old HDD
(sdf, bay 13) is now untouched — **keep it as a rollback** until Phase 2 proves
out (its systemd-boot entry still boots the old ext4 gen).

### Phase 2 — Attach SSD-B → mirror (brief, ~no downtime)
Insert SSD-B, then from `root@192.168.0.9`:

```bash
SSD_B=/dev/disk/by-id/<ata-SAMSUNG…second-unit>   # confirm via disk-bays
sgdisk -R "$SSD_B" "$SSD_A"        # replicate SSD-A's table
sgdisk -G "$SSD_B"                 # fresh GUIDs
sgdisk -c1:ESP-B -c2:rpool-B "$SSD_B"   # rename this disk's partitions
udevadm settle
mkfs.vfat -F32 -n BOOT /dev/disk/by-partlabel/ESP-B
zpool attach rpool /dev/disk/by-partlabel/rpool-A /dev/disk/by-partlabel/rpool-B
```

Resilver is fast (SSD, ~90G). Then deploy over LAN (`deploy --hostname
192.168.0.9 -s --targets .#beefcake`) — the `extraInstallCommands` now sees ESP-B
and mirrors `/boot` onto it. Verify `zpool status rpool` = mirror ONLINE, both
ESPs populated, and (ideally) yank one SSD in a test window to confirm the other
boots.

### Phase 3 — Cleanup
- Pull the old boot HDD (bay 13, serial S0K1VLAN) once the mirror is proven, plus
  any other retired rear-bay HDD.
- Merge this PR only after Phase 1 is live (the config is unbootable before then).

## Risks / notes
- **This config is unbootable until `rpool/root` exists.** Do not merge or deploy
  before Phase 1. Treat like the relocation PR (#619) — staged, hand-applied.
- Deploy beefcake over the **LAN** (`--hostname 192.168.0.9`), never the VPN
  (headscale runs here). See AGENTS.md.
- `disk-bays` (#638) is merged but not yet deployed to beefcake (gen 569 predates
  it); a Phase-1 `nixos-rebuild boot` will pick it up.
- Keep `boot.zfs.forceImportRoot` at its default for now (changing it is a
  separate, unrelated hardening PR).
