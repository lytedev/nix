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

What these deliberately do NOT cover (Phase 3+ on real hardware): bridge/MAC
takeover networking, libvirt vs microvm.nix substrate choice, virtio-blk perf
on spinners, the 12-disk draid3 import, fan/IPMI/smartd host tooling.
