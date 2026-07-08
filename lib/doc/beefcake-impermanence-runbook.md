# beefcake impermanence — Daniel's runbook

Written **to you, for your hands**. Every command here is yours to type;
whichever agent is around copilots and verifies. Design context:
`beefcake-impermanence-blue-green.md`; the flag it activates:
`packages/hosts/beefcake/impermanence.nix` (`lyte.impermanence.enable`).

---

## Part 0 — feet-wet exercises (do these before anything real)

No risk to production; all on dragon. Order matters — each builds a mental
model the next one uses.

1. **Touch the blue/green demo** (~20 min): from
   `prototypes/beefcake-impermanence/`: `nix run .#demo`, then in another
   terminal `ssh -p 2200 -i ~/.cache/beefcake-modelb-demo/ssh-key
   root@localhost`. Follow the MOTD tour: make a vaultwarden account at
   `http://localhost:8080`, validate green against clones, cut over, roll
   back. This is the future cutover UX in miniature.
2. **Walk the lite VM** (the real beefcake config): `bash lite/run-lite.sh
   run`, then `ssh -p 2300 -i ~/.cache/beefcake-lite/ssh-key
   root@localhost`. Poke: `systemctl status stalwart`, `zfs list` (note: no
   pools — storage is faked), `journalctl -u tuwunel`. This is what the
   deploy gate boots.
3. **Run the deploy gate yourself**: `deploy --validate=build -s --targets
   ".#beefcake"` with `LYTE_DEPLOY_GUARD_DRYRUN=1` set — watch the guard
   decide. Then a real `bash
   prototypes/beefcake-impermanence/lite/gate-deploy.sh` if you want the
   full 20-minute experience.
4. **Ephemerality hands-on**: in the lite VM, `touch /root/scratch`,
   `reboot` it (from inside), ssh back in — gone. That reflex ("is this
   path persisted?") is the whole impermanence mental model.

## Part 1 — the mental model after activation

- `/` = `rpool/local/root`, wiped to `@blank` by an initrd unit **every
  boot**. Anything not in the persist list or on a dataset does not survive.
- `/persist` = `rpool/persist` (SSD mirror): machine-id, ssh host keys
  (= the sops age identity), the `/var/lib` stragglers, `/root`, `/home`,
  `/srv`, `/var/log`, restic's cache.
- Unchanged: `/nix` (zstorage/nix), `/storage`, `/var/lib/containers`,
  `/var/lib/private` (already datasets), `/boot` (ESP-A, mirrored to B).
- **Your new best friend:** `zfs diff rpool/local/root@blank | less` — the
  complete list of everything that wrote outside the persist set since
  boot. Anything surprising there is either a persist-list gap or cruft.
- **2am card:** ssh as before (host keys persist — no fingerprint change).
  If ssh is dead: physical/iDRAC console; every pre-flip generation in the
  systemd-boot menu still boots the OLD untouched root (`rpool/root`) —
  that is the escape hatch, and it needs nothing from you in advance.

## Part 2 — prep (yours; any time; no reboot; ~30 min)

Preconditions: zstorage resilver finished (`zpool status zstorage`), the
disk agent's window closed, this PR merged (flag still OFF), current main
deployed or deployable.

```bash
ssh root@192.168.0.9   # or beefcake.internal.vpn.h.lyte.dev; then run bash
bash

# 1. the new datasets (rpool has ~200G free; this uses none until written)
zfs create -o mountpoint=none rpool/local
zfs create -o mountpoint=legacy rpool/local/root
zfs snapshot rpool/local/root@blank        # THE blank. Take it before ANY write.
zfs create -o mountpoint=legacy rpool/persist

# 2. warm-copy the persist set while services run (final delta happens in
#    Part 3; -aHAX preserves owners/modes/xattrs/hardlinks)
mkdir -p /mnt/persist && mount -t zfs rpool/persist /mnt/persist
mkdir -p /mnt/persist/etc/ssh /mnt/persist/var/lib /mnt/persist/var/cache
cp -a /etc/machine-id /mnt/persist/etc/machine-id
cp -a /etc/ssh/ssh_host_ed25519_key{,.pub} /etc/ssh/ssh_host_rsa_key{,.pub} /mnt/persist/etc/ssh/
for d in nixos systemd tailscale headscale hass clickhouse knot mosquitto \
         unifi jellyfin forgejo-db mautrix-discord mautrix-slack \
         mautrix-gmessages heisenbridge meshtasticd jmap-matrix-notify \
         forgejo-github-mirror music-assistant mmrelay hearth bitwarden_rs \
         kanidm caddy rancher; do
  rsync -aHAX --info=progress2 "/var/lib/$d" /mnt/persist/var/lib/ || echo "MISSING: $d (fine if service retired)"
done
rsync -aHAX /root /mnt/persist/
rsync -aHAX /home /mnt/persist/
rsync -aHAX /srv /mnt/persist/
rsync -aHAX /var/log /mnt/persist/var/
rsync -aHAX /var/cache/restic-backups-local /var/cache/restic-backups-rascal /var/cache/restic-backups-benland /mnt/persist/var/cache/
umount /mnt/persist
```

Sanity: `zfs list rpool/persist` should show roughly 60–90G used.

## Part 3 — the activation window (yours; ~30–45 min incl. reboot)

Announce the window (coordinator/other agents: no deploys). Then:

```bash
# on dragon, in a fresh workspace on current main:
#   flip the flag in packages/hosts/beefcake.nix:
#     lyte.impermanence.enable = true;
#   commit via PR or deploy a branch — your call; the deploy GATE will boot
#   the candidate as a VM first either way.

# 1. final state delta with services quiesced (on beefcake):
# from dragon, in the repo:
ssh root@192.168.0.9 'bash -s' < lib/doc/impermanence-final-delta.sh
# (stops the persist-set writers, re-runs the Part-2 rsyncs with --delete,
#  starts nothing — the reboot below brings everything up on the new root)

# 2. deploy the flag-on closure as a BOOT entry (never live-switch a root
#    change; the wrapper's validation gate runs first automatically):
deploy -s --targets ".#beefcake" -- --boot     # from dragon

# 3. reboot (this is the moment; ~12 min on this box):
ssh root@192.168.0.9 systemctl reboot
```

## Part 4 — verify (you, with the agent reading over your shoulder)

```bash
ssh root@192.168.0.9 bash    # same host keys -> no fingerprint warning. If
                             # you GET a warning, stop: something's off.
systemctl is-system-running        # want: running (give slow starters ~5 min)
systemctl list-units --state=failed
findmnt / /persist                 # / = rpool/local/root, /persist = rpool/persist
cat /etc/machine-id                # unchanged from before
zfs diff rpool/local/root@blank | head -40   # first look at root writes
curl -sk https://localhost --resolve git.lyte.dev:443:127.0.0.1 -o /dev/null -w '%{http_code}\n'
```

Mail/matrix/photos/git from your phone. Then leave it for a burn-in week;
check `zfs diff` daily-ish — every unexpected path is a persist-list PR.

## Part 5 — rollback (hopefully never; still yours)

At the systemd-boot menu (iDRAC console or physical): pick any pre-flip
generation — those boot the untouched old root (`rpool/root`) with the old
initrd, no rollback unit, no /persist dependency. The system is then exactly
what it was before Part 3. `/persist` keeps the newer copies of state; if
you stayed rolled-back for long, reverse-rsync the deltas before retrying.

## Troubleshooting quickies

| Symptom | First move |
|---|---|
| ssh fingerprint warning | host keys didn't persist — verify Part 2 step 2; rollback if unsure |
| a service lost state | its dir missed the persist list: check `zfs diff @blank`, rsync from `rpool/root` (old copy still there!), add to list, PR |
| boot hangs in initrd | iDRAC console: likely pool import; boot a pre-flip generation |
| sops secrets missing | `/persist` mounted? host keys present under `/persist/etc/ssh/`? |
| "where did my file in /root go" | it's ephemeral now unless under a persisted dir — check the list |
