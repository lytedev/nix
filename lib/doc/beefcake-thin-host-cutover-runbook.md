# beefcake thin-host cutover — Daniel's runbook

**Written to you, for your hands.** Phase 3 of
`beefcake-impermanence-blue-green.md`: demote today's bare-metal beefcake OS to
a **libvirt guest** under a thin hypervisor (`beefcake-host`), so a future
generation can be validated in a green slot before cutover (Phase 4). This is
the "big cutover," and — like the impermanence activation — it is
**boot-menu-reversible**: the pre-cutover generation still boots the bare-metal
beefcake off `rpool/root`.

Configs (all build clean; NOT deployed):
- `packages/hosts/beefcake-host.nix` — the thin host (libvirtd + NixVirt + br0 +
  impermanent root + owns zstorage). Declares the guest domain (`beefcake-blue`).
- `packages/hosts/beefcake/guest-hardware.nix` — the guest hardware layer;
  `beefcake-guest = beefcake.extendModules [ guest-hardware.nix ]` reuses ALL of
  beefcake's services + impermanence + sops.

Proven mechanisms this rides on: impermanence (LIVE on beefcake), the `/nix`
OverlayFS (`overlay-nix` M1 store-DB + `overlay-boot` M2 boot), Model B storage
(`modelb-storage`), and thin-host-runs-slots (`nix run .#demo`).

---

## The shape after cutover

```
beefcake-host (thin, impermanent, ~20G RAM)  owns rpool + zstorage
  └─ virsh domain beefcake-blue (= today's beefcake)
       OS disk : /dev/zvol/rpool/beefcake-blue  (rpool: root@blank + /nix base
                 + /nix-upper delta + /persist)
       /nix    : OverlayFS (RO base lower + RW per-slot upper)   [M2]
       zstorage: /storage, /var/lib/{containers,private} via virtiofs   [Model B]
       NIC     : virtio on br0, MAC b8:ca:3a:6d:2d:24  → 192.168.0.9 + v6 GUA
       identity: hostId 541ede55, same ssh host keys / sops age identity
```

**Recovery model (a strict improvement on today):** the HOST is reachable over
the LAN / its own tailscale regardless of the guest's state. An un-SSH-able
guest is reachable via `virsh console beefcake-blue` — replacing "drive to the
LAN". `on_crash=restart` keeps the guest up.

## Part 0 — feet-wet (on dragon, no prod risk)

1. `nix run .#demo` (prototypes/beefcake-impermanence) — the thin-host-runs-
   blue/green-slots tour in miniature (qemu-based ancestor of this).
2. `nix run .#overlay-boot-demo` — watch a system boot with `/nix/store` as the
   OverlayFS + a new path land in the upper (the guest's `/nix`).
3. Read the generated guest domain XML:
   `nix eval --raw .#nixosConfigurations.beefcake-host.config.virtualisation.libvirt.connections.\"qemu:///system\".domains` → the `.definition` store path; `cat` it (virtiofs shares + service MAC + OS disk).

## Part 1 — prep (yours; any time; NO downtime; the long pole)

All on the LIVE bare-metal beefcake (`root@192.168.0.9`). Nothing here disturbs
the running services.

```bash
bash   # host shell is fish

# 1. The guest OS zvol on the SSD-mirror rpool (sized for root+nix base+upper;
#    ~40G is ample — /nix base is a few G, the closure lives here not zstorage).
zfs create -V 60G -o volblocksize=16k rpool/beefcake-blue

# 2. Build the guest OS image (the guest's rpool: local/root@blank, local/nix =
#    the base closure, local/nix-upper empty, persist) and write it to the zvol.
#    The `beefcake-guest-image` disko target does exactly this:
#      img=$(nix build --no-link --print-out-paths .#nixosConfigurations.beefcake-guest-image.config.system.build.diskoImagesScript)
#      "$img"/bin/* --build-memory 8192        # produces main.raw
#      dd if=main.raw of=/dev/zvol/rpool/beefcake-blue bs=4M status=progress
#    (Build on dragon — the closure is cached there — or on the box.)

# 3. Seed the guest identity onto the guest /persist (before first guest boot):
#    the ssh host keys (= sops age identity) + machine-id, exactly as the
#    impermanence runbook did — recover from secrets/beefcake/host-identity.yml
#    if needed (master key). The guest reuses beefcake's identity verbatim.

# 4. zstorage stays put — the HOST imports it (beefcake-host owns it) and shares
#    /storage + /var/lib/{containers,private} into the guest via virtiofs. No
#    data move; verify xattr=sa + acltype=posixacl on those datasets (already so).
```

## Part 2 — the cutover window (yours; ~30–45 min incl. reboot)

Announce the window (coordinator: no deploys). beefcake is DOWN during the
reboot into the thin host.

```bash
# 1. Deploy beefcake-host as a BOOT entry (never live-switch a root change; LAN,
#    not VPN — headscale is in the guest, so the VPN is down during the window):
deploy --boot -s --targets ".#beefcake-host" --hostname 192.168.0.9

# 2. Reboot into the thin host (iDRAC/boot menu up FIRST — this is the moment):
ssh root@192.168.0.9 systemctl reboot
```

On boot: the thin host comes up, imports zstorage, `virtiofsd` exports the
shares, libvirtd autostarts `beefcake-blue`, the guest boots off its zvol,
overlays `/nix`, mounts the virtiofs shares, brings its NIC up as `eno1` with the
service MAC → the router hands it **192.168.0.9**, and every beefcake service
starts inside the guest exactly as before.

## Part 3 — verify (you, agent reading over your shoulder)

```bash
# HOST (its own mgmt IP on eno2, or LAN):
ssh root@<host-mgmt-ip> 'virsh list; virsh domblkstat beefcake-blue; systemctl is-system-running'

# GUEST (192.168.0.9, unchanged host keys → no ssh fingerprint change):
ssh root@192.168.0.9 'systemctl is-system-running; findmnt /nix/store /storage; \
  cat /etc/machine-id'   # overlay /nix + virtiofs /storage + stable identity
# From your phone: mail / matrix / photos / git / DNS / VPN all as before.
# virsh console beefcake-blue  # the new "2am console" — try it once on purpose.
```

## Part 4 — rollback (hopefully never; still yours)

At the systemd-boot menu (iDRAC/physical): pick the **pre-cutover generation** —
it boots the bare-metal beefcake off `rpool/root` (the old, non-thin-host root),
exactly as before Part 2. The guest zvol + zstorage are untouched; you can retry
after diagnosing. (This is why the cutover is boot-menu-reversible.)

## Troubleshooting quickies

| Symptom | First move |
|---|---|
| guest won't start | host: `virsh start beefcake-blue`; `journalctl -u libvirtd`; `virsh console beefcake-blue` for its boot |
| guest has no 192.168.0.9 | guest NIC not named eno1 / wrong MAC → check the domain `<mac>` + the `.link`; router reservation is by MAC |
| `/storage` empty in guest | virtiofs share/tag mismatch (host domain `<target dir>` vs guest `fileSystems` device) or virtiofsd not running |
| guest `/nix` not overlay | `overlay-nix-store.service` in the guest (after zfs-mount, before nix-daemon) — see overlay-boot M2 gotchas |
| sops secrets missing in guest | guest `/persist/etc/ssh/` host keys present? (= the age identity) |
| pool double-import panic | structurally prevented — only the HOST imports zstorage; the guest gets virtiofs, never the pool |

## Not in this phase

- **Green slot + `beefcake-cutover` tool** (validate-against-clones on an
  isolated net, snapshot, service-MAC+disk move, one-command rollback) — BUILT
  (Phase 4, `beefcake-host`); runtime-validated on the thin host itself (the
  demo proved the flow end-to-end). `beefcake-cutover status|validate|
  validate-done|cutover|rollback`.
- **`beefcake-guest-image` disko builder** (Part 1 step 2) — BUILT; evaluates.
- A deploy-rs node for `beefcake-host` — added; the guest deploys as
  `.#beefcake` into the active slot as today.

Everything above is config + tooling that builds; the remaining work is
intrinsically real-hardware: the actual cutover (this runbook) and its runtime
validation, which can't be nested at beefcake's 250G/80-service scale.
