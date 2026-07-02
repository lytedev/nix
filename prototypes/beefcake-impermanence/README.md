# beefcake impermanence + blue/green prototypes

Companion to `lib/doc/beefcake-impermanence-blue-green.md` (§7) and
`issues/open/blue-green.md`. Standalone flake — own lock, zero impact on the
main flake's eval or CI. Intended to run on **dragon** (needs `/dev/kvm`).

⚠️ Everything under `keys/` is **test-only material generated for these
prototypes** (age key, sops file encrypted to it, ssh keypair). Nothing here
grants access to anything real; do not reuse outside the prototypes.

| Artifact | What it proves | Run |
|---|---|---|
| `checks.semantics` (P1a) | Impermanence *semantics* on a wiped root: `/persist` carries postgres + DynamicUser (`/var/lib/private`) state, sops-nix decrypts unattended (age identity under `/persist`), machine-id + ssh host key stable, root file vanishes. | `nix build .#checks.x86_64-linux.semantics` |
| `apps.rollback-demo` (P1b) | The *mechanism* end-to-end, as beefcake would run it: disko-built ZFS-root image, EFI → systemd-boot → **systemd-initrd `zfs rollback` unit** (the `postDeviceCommands` folklore does nothing under systemd-initrd) → boot twice → root wiped, `/persist` survives. | `nix run .#rollback-demo` |
| `checks.handoff` (P2) | Blue/green cutover: two guests sequentially own a shared raw disk carrying a ZFS pool (zstorage stand-in, whole-disk virtio-blk); blue seeds postgres state → export → green imports + serves + writes → rollback to blue with all state. Plus green's no-pool "validation boot". | `nix build .#checks.x86_64-linux.handoff` |
| `checks.modelb-storage` (P3) | Model B primitives: postgres on ext4-on-zvol; snapshot+clone taken while it runs, opened by a second instance (validation vs live real state); two-way write isolation; clean clone discard; xattr/posixacl on a share dataset. | `nix build .#checks.x86_64-linux.modelb-storage` |

## Hands-on demo (`nix run .#demo`)

A **persistent, interactive** environment — not an assert-and-vanish test. A
"thin host" VM (nested KVM) owns a ZFS pool and manages blue/green slot VMs
running REAL services in the Model B shape: **vaultwarden** (sqlite on the
9p-shared dataset; 9p stands in for virtiofs here), **postgres** (on a
zvol-backed directory), **caddy**. Slots have tmpfs roots and get their
closures from the host's (dragon-shared) store — the DD2/DD3 properties,
touchable.

```
nix run .#demo        # this terminal becomes the demo host's serial console
# elsewhere:
ssh -p 2200 -i demo-state/ssh-key root@localhost   # the demo host
# (the launcher installs a 0600 copy of the test key at demo-state/ssh-key —
#  the repo copy is 0644, which ssh refuses)
```

Tour (commands on the demo host; the MOTD repeats this):
1. `slot-run blue && vip-set blue` → browse http://localhost:8080, create a
   vaultwarden account + save an entry (real state!)
2. `slot-run green validate` → green boots the candidate generation against
   **ZFS clones** of the live state with **egress cut** (`restrict=on`).
   Browse http://localhost:8082 — your entry is there; anything you change
   is discarded at `slot-stop green`.
3. `cutover green` → pre-cutover snapshot, blue stops, green starts with the
   REAL state, VIP repoints. Your entry survived; `cutover blue` = the
   one-step rollback.

State (pool vdev, `/var/lib/demo`) persists across demo-host restarts in
`./demo-state/` (gitignored). Slot roots are tmpfs — wiped every boot, on
purpose.

What the prototypes deliberately do NOT cover (Phase 3+ on real hardware):
bridge/MAC takeover networking, virtiofs transport (9p in the demo; dataset
semantics proven in P3), libvirt vs microvm.nix substrate choice, virtio-blk
perf on spinners, the 12-disk draid3 import, fan/IPMI/smartd host tooling.
