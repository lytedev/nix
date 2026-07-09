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
         kanidm caddy rancher kubelet cni redis-immich redis-paperless \
         samba NetworkManager sops-nix mautrix-meta-facebook \
         mautrix-meta-instagram mautrix-whatsapp; do
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
#    change; the wrapper's validation gate runs first automatically).
#    --boot is a deploy-rs flag ("update the boot loader, don't activate") — it
#    MUST come before `--`; putting it after `--` passes it to `nix build`,
#    which silently does a LIVE SWITCH instead (wedge risk). Deploy over the
#    LAN, not the VPN: beefcake runs headscale and a VPN deploy severs itself.
deploy --boot -s --targets ".#beefcake" --hostname 192.168.0.9     # from dragon

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

## Part 6 — Retry #3: the proper reboot test (the current step)

Where we are (2026-07-08): the flag is already ON and beefcake is **running
the impermanent root right now** (gen 608) — but only because three fixes were
applied by hand across two flip attempts. Two of them are baked into
generation 608 (machine-id, #726). The third, the sops-initrd + `/var`-perms
fix (**PR #727**, `beefcake-impermanence-boot-fixes`), is on the branch but was
patched onto the *live* system by hand — it is **NOT in the running closure**.
So a plain reboot today would regress the sops-initrd path and come up
degraded. Retry #3 = bake #727 into a boot entry and reboot to prove a *clean*
boot with everything encoded. No datasets, no migration — the state is already
on `/persist`; this is just a deploy + reboot.

**Pre-flight (do every time — the no-downgrade rule):**

```bash
# in the workspace with #727 checked out:
#   code/workspaces/nix/beefcake-impermanence-blue-green
jj git fetch                                   # never deploy a stale checkout

# what beefcake runs now (note the date + rev suffix):
ssh root@192.168.0.9 readlink /run/current-system
#   -> ...-nixos-system-beefcake-26.05.20260623.667d5cf   (2026-06-23)

# what #727 will build — same nixpkgs (nixpkgs_4=667d5cf), so NOT a downgrade
# and NOT a cross-release: config + initrd change only, no toolchain re-exec:
nix eval --raw .#nixosConfigurations.beefcake.config.system.nixos.label
#   -> 26.05.20260623.667d5cf   (must match the date/rev above, or STOP)
```

**Deploy + reboot:**

```bash
# 1. boot entry only — no live activation (so no dbus-reexec wedge); the gate
#    boots the candidate as beefcake-lite first. LAN, not VPN (headscale).
deploy --boot -s --targets ".#beefcake" --hostname 192.168.0.9

# 2. have the boot menu / iDRAC virtual console up BEFORE you reboot, so you
#    can watch stage-1 and drop to a pre-flip generation if it hangs.
ssh root@192.168.0.9 systemctl reboot          # ~12 min on this box
```

Then run **Part 4** verification. The specific things #727 is proving on a
clean boot (all of which failed on the by-hand path before the fix):

```bash
ls /run/secrets | wc -l                        # want ~44, not 0 (sops in initrd OK)
stat -c '%a' /var /var/lib                      # want 755 755 (not 700)
systemctl is-system-running                     # want: running, 0 failed
```

If all green: this is the real proof — **now** merge #727 (verify-before-merge)
and re-pin the boot default so unattended reboots stay on the impermanent root:

```bash
ssh root@192.168.0.9 bootctl set-default nixos-generation-<new>.conf
```

Rollback is unchanged (**Part 5**): boot any pre-flip generation (gen 606 is
still there) from the menu.

**Deferred to their own fast-follow PRs (NOT in the reboot test):** provisioning
the ed25519 host key declaratively (encrypted in-repo to the master key, laid
on `/persist` at setup — so identity is intentional, not install-random state);
and a VM regression guard for the `/var`-perms class.

## Recovery: host identity (fresh or lost `/persist`)

beefcake's identity keys are backed up, encrypted to your master key, in
`secrets/beefcake/host-identity.yml`: the ed25519 + rsa ssh host keys. The
**ed25519 key IS the sops age identity** (`age1etv56f…=sshd-at-beefcake`, a
recipient on every beefcake secret), so it cannot be laid by sops-nix at
runtime — it's the thing sops needs to decrypt everything else. It is a
bootstrap artifact you place **off-host, before first boot**.

If `/persist` is ever rebuilt (fresh SSD, disaster recovery), restore the
identity from a machine holding the master key (dragon) **before** booting the
impermanent root — otherwise a fresh install generates a NEW key, the derived
age recipient changes, and sops decrypts nothing:

```bash
# from the repo, with the master age key available:
mkdir -p /tmp/bkid && cd /tmp/bkid
for k in ssh_host_ed25519_key ssh_host_rsa_key; do
  sops -d secrets/beefcake/host-identity.yml | yq -r ".${k}_b64"     | base64 -d > $k
  sops -d secrets/beefcake/host-identity.yml | yq -r ".${k}_pub_b64" | base64 -d > $k.pub
  chmod 600 $k; chmod 644 $k.pub
done
# place onto the new /persist (adjust the path to how it's mounted during recovery):
scp ssh_host_* root@192.168.0.9:/persist/etc/ssh/
shred -u ./*        # don't leave plaintext keys lying around
```

The keys are dated at beefcake's original install (2024-09-03); keeping them
means the ssh fingerprint never changes and sops keeps working across a
`/persist` rebuild. To verify a restored key derives the expected recipient:
`ssh-keygen -y -f ssh_host_ed25519_key | ssh-to-age` → `age1etv56f…`.

## Troubleshooting quickies

| Symptom | First move |
|---|---|
| ssh fingerprint warning | host keys didn't persist — verify Part 2 step 2; rollback if unsure |
| a service lost state | its dir missed the persist list: check `zfs diff @blank`, rsync from `rpool/root` (old copy still there!), add to list, PR |
| boot hangs in initrd | iDRAC console: likely pool import; boot a pre-flip generation |
| sops secrets missing | `/persist` mounted? host keys present under `/persist/etc/ssh/`? |
| "where did my file in /root go" | it's ephemeral now unless under a persisted dir — check the list |
