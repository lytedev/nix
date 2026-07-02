# beefcake: impermanence + thin-hypervisor blue/green — design

**Status:** design + prototype phase (2026-07). Companion issue:
`issues/open/blue-green.md`. Investigation notes and full inventories were
gathered live on 2026-07-01 (repo config sweep + read-only audit of the running
host + prior-art research); the load-bearing facts are inlined here.

**Goal:** make beefcake structurally safe to deploy by (1) making all of its
state *explicit* (nix-impermanence), then (2) demoting today's bare-metal OS to
a **guest VM** under a thin NixOS hypervisor host, so a new generation can be
**validated in a green slot before cutover**, with one-step rollback.

---

## 1. Where beefcake is today (facts that shape the design)

Hardware: Dell R720xd, 2× Xeon E5-2680 v2 (40 threads), **251 GiB RAM** (no
swap), 4× Intel I350 GbE (only `eno1` connected). All disks — the 12-bay
backplane *and* the boot/rear disks — hang off a **single crossflashed IT-mode
LSI SAS2308 HBA** (`02:00.0`) behind a SAS expander (verified via
`/sys/block/*` device paths). There is no usable second disk controller today.

Storage:

- `zstorage` — 21.8 T draid3 (`draid3:3d:8c:2s`), the real payload. Holds
  `/storage` (3.2 T), `/nix` (!, `zstorage/nix`, 627 G incl. snapshots),
  `/var/lib/containers` + `/var/lib/private` (ZFS-native mounts, migrated
  2026-06-29, **deliberately not in `fileSystems`** — see
  `issues/closed/beefcake-relocate-state-to-pool.md`).
- `/` — **plain ext4 on a single 300 G 10K SAS spinner** (`sdf2`), with the
  512 MB ESP on the same disk. This is the SPOF the SSD-mirror project
  (2× PM863a purchased) is meant to fix.
- `rpool` — a single Samsung PM863 240 G SSD carrying an *unused* alternate
  root (`/mnt/rpool-root`, read-only).

Ext4-root residue (the impermanence work list, ~69 G live): `/var/cache` 52 G
(restic caches ×3), `/var/log` 3.3 G, and — critically — **plain `/var/lib`
dirs still on the spinner** for headscale, hass, clickhouse, knot, mosquitto,
unifi, vaultwarden(?), jellyfin cache, mautrix-*, redis, forgejo-db, kanidm and
friends, plus `/etc/machine-id`, `/etc/ssh/ssh_host_*` (the sops-nix age
identity), `/root`, `/home`. Another ~89 G of shadowed pre-migration originals
sits invisibly under the ZFS overlay mounts (reclaim pending).

Virtualization readiness: VT-x + `/dev/kvm` ready; **VT-d (IOMMU) is OFF**
(BIOS + `intel_iommu=on` both missing); no libvirt/qemu installed. The I350
NICs are SR-IOV-capable; three ports are unplugged.

Workload (~80 native services + 6 podman containers + k3s): mail (stalwart),
matrix (tuwunel + 5 bridges), git (forgejo + runners), DNS (knot, hidden
primary for lyte.dev), VPN (headscale + tailscale exit node + DERP), identity
(kanidm), photos/media (immich/jellyfin/audiobookshelf), home automation
(hass + wyoming + music-assistant + mqtt), postgres 17 + clickhouse, caddy as
sole :443 edge, samba/avahi/wsdd, k3s + traefik, minecraft. Full service→state
map lives in the inventory (see §9 backup-gaps table for the risky subset).

Existing pain this design must fix (from `issues/open/blue-green.md`, the
2026-06-28 incident): live `switch` is all-or-nothing; a stale-workspace deploy
downgraded nixpkgs → systemd re-exec wedge → redis RDB-format refusal →
services dropped; recovery was manual surgery. Guards today are procedural
(AGENTS.md rules + devshell deploy wrapper), not structural.

**It happened AGAIN mid-design (2026-07-02, ~29 min outage), and this time the
config was innocent:** a same-nixpkgs deploy (another agent's immich-oauth
work) live-switched beefcake; the switch stopped ~70 services, wedged before
its restart phase (caddy stop-timeout→SIGKILL), the deploy session died, and
deploy-rs rolled the profile back leaving the box running an unrecorded
closure with the service herd `inactive` — note: *inactive*, not *failed*, so
a `systemctl --failed` sweep alone under-reports a stopped world. Recovery =
reboot into the staged known-good generation. The failure was pure
live-switch *mechanics* — stop-the-world, then hope — which is precisely what
DD6's cutover model (validated green slot; the serving instance never
live-switches) eliminates. Ops lessons folded in: detach long remote
mutations (`systemd-run`), census `is-active` on key services not just
`--failed`, and multi-agent recoveries must be coordinated through Daniel
(two well-meaning recoveries collided here, again).

---

## 2. Target architecture

```
┌────────────────────────────────────────────────────────────────────┐
│ beefcake-host (thin hypervisor, NixOS, impermanent)                │
│  root: rpool2 = ZFS mirror on 2× PM863a SSD, blank-snapshot        │
│        rollback each boot; /persist dataset for host identity      │
│  runs: sshd, libvirtd (or microvm.nix), br0(eno1), smartd +        │
│        disk-bays + IPMI fans, node exporter                        │
│                                                                    │
│  ┌──────────────────────────────┐  ┌──────────────────────────────┐│
│  │ beefcake-blue (ACTIVE)       │  │ beefcake-green (candidate)   ││
│  │ = today's beefcake config    │  │ same closure family, next    ││
│  │ OS disk: zvol on rpool2      │  │ generation; OS zvol on rpool2││
│  │ /nix inside OS zvol          │  │                              ││
│  │ owns zstorage: 12 whole      │  │ validation boot: NO pool,    ││
│  │ disks via virtio-blk,        │  │ synthetic/fixture state,     ││
│  │ imports pool itself          │  │ isolated validation network  ││
│  │ NIC: virtio on br0 with the  │  │ cutover: disks + service MAC ││
│  │ “service MAC” → keeps        │  │ move here atomically         ││
│  │ 192.168.0.9 via router       │  │                              ││
│  │ reservation                  │  │                              ││
│  └──────────────────────────────┘  └──────────────────────────────┘│
└────────────────────────────────────────────────────────────────────┘
```

### Design decisions (with the reasoning that picked them)

**DD1 — Impermanence mechanism: ZFS blank-snapshot rollback, not tmpfs.**
For a box with ~100 services and unpredictable write patterns, tmpfs-root risks
RAM exhaustion; ZFS rollback costs nothing at runtime, and `zfs diff
pool/root@blank` becomes a free, continuous **state-discovery audit** (the
exact tool needed to build/verify the persist list). Canonical pattern:
[Erase your darlings](https://grahamc.com/blog/erase-your-darlings/).
⚠️ The widely-copied `boot.initrd.postDeviceCommands` rollback hook **does not
run under systemd-initrd**; use an initrd systemd service ordered after
`zfs-import-<pool>.service` and before `sysroot.mount`
([modern recipe](https://notthebe.ee/blog/nixos-ephemeral-zfs-root/)). The
prototype must prove this.

**DD2 — Who owns `zstorage`: the HOST (Model B). Revised 2026-07-01 with
Daniel; pending the Model-B storage prototype.**
Options considered:

| Option | Verdict |
|---|---|
| (a) HBA PCI passthrough to guest | Cleanest for the guest, but the ONE HBA also drives the host's boot disks — the host would have nothing to boot from. Needs VT-d enabled + host boot moved off the backplane (e.g. a PCIe NVMe adapter). **Deferred as a future upgrade**, not required. |
| (b) **Host owns pool; guests get virtiofs shares of the existing datasets + zvols for databases** | High-fidelity green validation via ZFS **clones** (the killer feature — see DD6); `/nix` stays on `zstorage/nix` as the HOST's store, shared read-only into both slots (dissolves the 240 G SSD budget problem — no per-slot OS zvols); today's dataset layout survives (virtiofs shares the same trees — no 3.8 T relayout, only DB dirs move onto zvols). **Chosen (2026-07-01), pending prototype proof of postgres-on-zvol handoff + virtiofs data plane.** |
| (c) Guest owns pool; host passes 12 raw disks as virtio-blk | Minimal guest-config delta and the handoff mechanics are proven (prototype P2 passed), but: no clone-based validation (the pool is importable by only one slot at a time), forces ~100 G per-slot OS zvols onto a 240 G SSD mirror, and cannot share `/nix`. **Demoted to fallback** if Model B's virtiofs/zvol fidelity disappoints. |

Consequences of (b): the host imports zstorage — its own `/nix` can literally
remain `zstorage/nix`, today's layout. ZED/scrub/smartd/`disk-bays`/ZED alerts
ALL stay on the host: one storage domain from hardware to filesystems. Guests
become pure compute shells consuming three attachment types, and **"give this
service a zvol-backed directory" is a first-class primitive** (Daniel's
requirement) — a per-service declaration in the service's own module
(analogous to the `services.restic.commonPaths` idiom) that provisions the
zvol host-side, attaches it virtio-blk to the active slot, and mounts it at
the service's dataDir:

1. **virtiofs share** — default for file trees (`/storage/*` media, forgejo
   repos, syncthing, samba shares); the shared datasets need `xattr=sa` +
   `acltype=posixacl`.
2. **zvol, virtio-blk, ext4 inside** — for fsync-heavy or format-sensitive
   state: postgres, stalwart + tuwunel RocksDB, sqlite-heavy dirs if virtiofs
   semantics ever bite. Snapshot/clone granularity becomes whole-volume
   instead of per-file — acceptable, and the host still snapshots zvols.
3. **host-store read-only share** — `/nix/store` into every slot
   (microvm.nix's ro-store pattern) with a small writable overlay; guest
   closures live in the host's store.

Deploy-model consequence: guest generations are built into the HOST's store;
"deploy beefcake" becomes "host pins the new guest closure; the target slot
(re)starts into it". The host being the deploy chokepoint is what finally
makes the no-downgrade guard *structural*: host tooling compares candidate vs
running closure before any slot may start.

**DD3 — Slot roots: tiny generated images over the shared host store.**
(Rewritten for Model B — the original per-slot-OS-zvol design is obsolete.)
Blue and green coexist as two closures in the host store; each slot's root is
a small disposable image (erofs/squashfs + tmpfs overlay, microvm-style) —
impermanent *by construction*, which is the same discipline the persist list
already enforces. The 240 G SSD mirror now only carries the host's own
(blank-rollback) root + ESPs; the host store, guest closures and all state
live on zstorage.

**DD4 — Hypervisor substrate: libvirt (declaratively wrapped), microvm.nix as
the evaluated alternative.** For one or two heavyweight guests, libvirt/qemu
gives virtio-blk whole-disk attach, PCI hotplug later, virtlockd exclusivity,
and mature ops tooling (`virsh` console/shutdown). microvm.nix's strengths
(many small VMs, ro-erofs roots) matter less here, but its "host rebuild
doesn't restart guests" property and clean flake integration make it a real
contender — the blue/green prototype should try the disk-handoff mechanic on
plain qemu (which is what both reduce to) and the final pick can follow
ergonomics. NixVirt or hand-templated domain XML keeps libvirt declarative.
nspawn/nixos-containers were rejected: shared kernel can't give the guest its
own ZFS or survive host-userspace wedges — the incident class we're fixing
includes systemd re-exec wedges, which containers share with the host.

**DD5 — Networking: bridge + MAC-anchored identity.**
Host owns `eno1` in a bridge `br0`; the **active** slot's virtio NIC carries a
fixed "service MAC" and the router's DHCP reservation for `192.168.0.9` moves
(once) from the physical NIC's MAC to that service MAC. The host gets its own
IP/reservation (new: host and beefcake-guest are separately reachable — the
"deploy over LAN because headscale lives on it" problem finally gets a clean
answer: the *host* is reachable even when the guest's headscale is mid-restart,
and hosts a serial/virsh console into the guest). Cutover = detach service NIC
from blue + attach to green (or stop blue / start green with the same NIC
definition): same MAC ⇒ same IP, switches learn the move on first frame; L2
services (avahi/mDNS, wsdd, SlimProto, DHCP) keep working because the bridge is
the same segment. Green's validation boot uses a *different* MAC on an isolated
host-only network so it can never collide with production. eno2–4 stay
available for a future dedicated validation/管理 uplink or SR-IOV.

**DD6 — Blue/green semantics: validate against CLONES, cut over with a
bounded stop.** With single-writer state (postgres, RocksDB, sqlite
everywhere) there is no zero-downtime dual-write; the honest model — much
stronger under Model B, because validation runs against *clones of the real
data*:

1. **Green validation (no downtime, no risk to real data — by construction):**
   host snapshots every state dataset/zvol and gives green **ZFS clones** of
   all of them. Green boots the candidate generation against a byte-identical
   copy of production state: every "new version refuses old data" failure
   (the redis-RDB incident class) surfaces here, with full-size real data,
   at zero copy cost. Green's writes land in the clones, which are discarded
   afterward — the origin datasets are untouchable through the clone.
   Health gate: no failed units, per-service smoke checks (see below),
   `nixpkgs` date ≥ blue's (structural no-downgrade), data stores actually
   opened their cloned state.
   ⚠️ **Quiesce before snapshot** (found empirically in the hands-on demo):
   sqlite under `synchronous=NORMAL` (vaultwarden et al.) does NOT fsync
   per-commit — committed writes sit in the guest page cache, so a live
   host-side snapshot misses them on ANY transport (9p/virtiofs/zvol). A
   registered vaultwarden account was absent from the validation clone until
   the tooling learned to `sync` the active slot first. Postgres/RocksDB are
   immune (they fsync their WALs). Corollary for cutover: **slot shutdown
   must be a clean guest poweroff**, never SIGTERM-the-VMM, or the same
   cached writes die with the process.
   ⚠️ **Egress isolation is mandatory**: a green slot holding cloned real
   state runs real services with real credentials — its stalwart would try
   to deliver queued mail, bridges would double-post, DDNS would fire. The
   validation network must be egress-blocked (host-only + explicit
   allowlist); this is the main "pull it off correctly" hazard, and it's a
   *duplicate-actions* hazard, not a data-loss one.
2. **Per-service smoke checks:** each service module declares its own
   validation probe alongside its config (same aggregation idiom as
   `services.restic.commonPaths` — e.g. `lyte.validation.checks`): "unit
   active" plus a data-plane assertion that exercises loaded state (psql
   query against a known table, redis PING+DBSIZE, headscale nodes list,
   forgejo API hit, IMAP login). The same registry doubles as the
   post-cutover health gate.
3. **Cutover (minutes, controlled):** fresh `zfs snapshot -r` savepoint →
   stop blue's services (clean unmount/detach of shares + zvols) → attach
   the REAL datasets/zvols + service NIC to green → green starts services →
   run the same smoke-check registry → done.
4. **Rollback (one step):** reverse the attachment; blue's generation is
   untouched. State changes during green's tenure are bounded by the
   pre-cutover snapshot (restoring it is an explicit, documented decision,
   not surprise data loss).

Ordinary low-risk config tweaks can still be plain deploys into the active
guest; the blue/green path is for kernel/nixpkgs/systemd/db bumps — exactly the
class that must never live-switch today (cross-release rule).

**DD7 — The old bare-metal system stays bootable as the final rollback.**
The 300 G spinner (today's root) is left intact and out of the VM story. If the
hypervisor world fails badly, boot the spinner and beefcake is bare-metal again
(both configs mount the same zstorage state at the same paths — one world at a
time). This makes the big migration day reversible at the firmware-boot-menu
level.

---

## 3. Impermanence design (applies to bare-metal now, guest later)

The persist list is *the* deliverable; the VM/blue-green story consumes it.

Datasets (names bikesheddable):

```
zstorage/state              mountpoint=/persist        (new)
zstorage/varlib-private     mountpoint=/var/lib/private  (exists)
zstorage/containers         mountpoint=/var/lib/containers (exists)
zstorage/storage            mountpoint=/storage        (exists)
zstorage/nix                (host store under Model B — today's layout, kept)
zstorage/zvols/<service>    (DD2 primitive: per-service zvol-backed dirs)
rpool2/local/root           ← blank-rollback (host root; slot roots are
                              generated images, see DD3)
```

`environment.persistence."/persist"` (impermanence module), initial list —
compiled from the config sweep + live ext4-root audit:

- **Identity/boot-critical (files):** `/etc/machine-id`; ssh host keys via
  `services.openssh.hostKeys[].path = "/persist/etc/ssh/…"` (NOT a bind of
  /etc/ssh) — these are also the **sops-nix age identity**, so they must exist
  before secret decryption; keeping the same keys keeps `secrets/beefcake/*`
  decryptable with zero re-keying.
- **Directories still on ext4 root today:** `/var/lib/headscale`,
  `/var/lib/hass`, `/var/lib/clickhouse`, `/var/lib/knot`,
  `/var/lib/mosquitto`, `/var/lib/unifi`, `/var/lib/jellyfin` (cache/config
  residue; media already on /storage), `/var/lib/forgejo-db`,
  `/var/lib/mautrix-{discord,slack,gmessages}`, `/var/lib/heisenbridge`,
  `/var/lib/redis-*`, `/var/lib/meshtasticd`, `/var/lib/jmap-matrix-notify`,
  `/var/lib/forgejo-github-mirror`, `/var/lib/music-assistant`,
  `/var/lib/mmrelay`, `/var/lib/hearth`, `/var/lib/vaultwarden`(verify —
  module may already point at /storage), `/var/lib/kanidm`(verify vs
  /storage/kanidm), `/var/lib/nixos` (uid/gid maps — required),
  `/var/lib/tailscale` (node key!), `/var/lib/systemd` (persistent timers,
  coredump config), `/var/log` (journal + caddy logs; or accept loss),
  `/root` (small; contains runbooks/scripts today), `/home` (2.5 G),
  `/srv/h.lyte.dev`.
- **Deliberately ephemeral:** `/var/cache` — EXCEPT `/var/cache/restic`
  (decided 2026-07-01: persist it, dedicated dataset, snapshots off, with a
  config comment explaining it's a rebuildable metadata cache kept only so
  post-reboot backup runs don't re-fetch repo indexes from the two remote
  sftp repos); `/tmp`; podman graph roots already on their dataset.
- `/var/log`: persist (trivially small; journald is already capped fleet-wide
  at `SystemMaxUse=1G` in `default-module.nix` and shipped to OpenObserve via
  the OTel collector, so this is belt-and-suspenders for local debugging, not
  a retention decision).
- The June relocation's symlink layer (`/var/lib/X → private/X`) gets
  superseded by real persistence entries; the not-in-`fileSystems` ZFS-native
  mounts get declared properly once the shadowed originals are reclaimed
  (mount ordering: `zfs-mount` vs impermanence binds — prototype verifies).

**Completeness verification** (no first-party dry-run exists —
[impermanence#240](https://github.com/nix-community/impermanence/issues/240)):

1. `zfs diff rpool2/local/root@blank` on the running system → anything not in
   the persist list is a finding (this audit is free forever — DD1).
2. A **nixosTest harness**: boot the config, exercise services, reboot (root
   wiped), assert every service's state survived + `machine-id` stable + sops
   secrets decrypt. This harness is the reusable regression gate for "did we
   forget a StateDirectory".
3. Burn-in on the physical box for ≥2 weeks before the VM migration relies on
   the same list.

**sops-nix ordering on a wiped root** (the one folkloric bit — prototype must
prove): `sops.age.sshKeyPaths` → persisted host-key path; secret decryption
runs in activation, so the only hard requirement is that `/persist` is mounted
in initrd (`neededForBoot = true` on the dataset's mount) — the nixosTest
asserts a service consuming a sops secret starts on second (wiped) boot.

---

## 3b. Service → storage-class map (all of them)

The prototypes prove one representative per *storage-behavior class*; every
beefcake service falls into a class. This map is the Phase-1 work list — each
row becomes a `zvol`/`share` declaration plus a `lyte.validation.checks`
smoke probe.

**Class Z — zvol-backed dir (fsync-disciplined or format-sensitive; live
snapshots are crash-consistent-safe). Representative PROVEN: postgres (P3 +
demo).**
- postgres 17 (all DBs: atuin, plausible, immich, daniel) — smoke: `SELECT`
  against each DB
- stalwart (RocksDB — fsync'd WAL; the mail store) — smoke: IMAP login +
  JMAP /healthz
- tuwunel (RocksDB) — smoke: /_matrix/client/versions + login
- clickhouse (plausible) — smoke: trivial query
- unifi mongodb — smoke: controller API ping
- redis instances (AOF/RDB; loss window is redis-inherent) — smoke: PING +
  DBSIZE (catches the RDB-format incident class)
- k3s (etcd fsyncs raft WAL; containerd images rebuildable) — smoke:
  `kubectl get nodes` Ready
- openobserve + spacetimedb (own on-disk stores, fsync behavior unaudited →
  zvol to be safe) — smoke: HTTP health endpoints
- forgejo's sqlite (`/var/lib/forgejo-db`) — deliberately on SSD for perf
  today, so zvol (not share) despite being sqlite — smoke: web + git-over-ssh
  clone

**Class S — share + QUIESCE hook (sqlite-WAL family; `synchronous=NORMAL`
commits sit in guest page cache — the demo's vaultwarden finding).
Representative PROVEN: vaultwarden (user-level, incl. clone-login).**
- headscale, hass (sqlite recorder), paperless (sqlite + documents),
  mautrix-{discord,slack,gmessages}, heisenbridge, matrix-hookshot, hearth,
  jmap-matrix-notify, mmrelay, audiobookshelf, music-assistant,
  forgejo-github-mirror, meshtasticd — smoke per service: unit active +
  cheapest data-plane read (e.g. `headscale nodes list`, HA API ping,
  bridge /live)

**Class F — plain share (flat files; no write-ordering sensitivity). Dataset
semantics PROVEN in P3 (xattr/acl) + demo (9p).**
- /storage media (jellyfin, immich originals, audiobookshelf files), samba
  shares (family/valerie/daniel/public), files.lyte.dev, /srv cdn, roms,
  minecraft world dirs (JVM writes are periodic saves — snapshot-safe
  enough; smoke: server MOTD ping), syncthing folders (its index db
  self-heals by rescan; syncthing is itself a replication layer)

**Class E — ephemeral (never persisted, rebuilt on boot):**
- /var/cache except restic's, gitea-runner workdirs (tmpfs today), jellyfin
  transcode cache, podman *images* (volumes/state live in Z/S above)

**Class H — leaves the guest entirely (host concerns):**
- smartd + disk-bays + ZFS ZED/scrub + IPMI fans + disk-alerts, the slot
  lifecycle + no-downgrade gate, (host's own node exporter → guest's
  OpenObserve)

Cross-cutting, already designed: caddy (certs re-issuable, state on a share;
smoke: :443 for a known vhost), knot (zone files regenerable from git +
dynamic updates; smoke: SOA query), tailscale/headscale node keys (class S),
podman graph (`zstorage/containers` stays a dataset mounted into the slot
via share... or the graph moves to a zvol if overlay-on-9p/virtiofs
misbehaves — **flagged for Phase-3 verification**).

### Honest residual risk (what no dragon-scale test can prove)
1. **virtiofs transport** at scale (demo used 9p) — Phase 3 on real hardware.
2. **overlayfs (podman) on a virtiofs share** — may need the graph on a
   zvol; known-fiddly combination.
3. **The full closure booting as a slot** — config-level (hardware/network
   swap) is testable by eval + a trimmed-profile boot on dragon; the full
   ~80-service boot needs beefcake's RAM and happens as Phase 3's first
   validation boot.
4. RocksDB clone-recovery (stalwart/tuwunel) is *argued* safe (fsync'd WAL,
   same class as postgres) but not yet demonstrated — cheap to add to P3 if
   we want the receipt before touching mail.

---

## 4. Migration path

Sequenced so every phase delivers standalone value and has its own rollback.

**Phase 0 — hygiene (now, no reboot, PR-sized chunks):**
- Add `/var/lib/headscale` to restic `commonPaths` — the tailnet DB is
  currently unbacked-up (also decide clickhouse + caddy ACME state). ← do
  regardless of everything else.
- Reclaim the ~89 G shadowed originals + finish `*.old` cleanup (post-resilver,
  next maintenance window).
- Declare the existing ZFS-native mounts (`containers`, `varlib-private`) in
  config (ordering-safe form) so a rebuild elsewhere reproduces them.

**Phase 1 — impermanence, proven in VMs on dragon (no beefcake risk):**
- Build the persist list + impermanence module config for beefcake behind a
  flag (`lyte.impermanence.enable`), OFF for the physical host initially.
- Build the nixosTest harness (§3) + a disko-built qemu image on dragon that
  boots the ZFS-blank-rollback root twice and proves rollback + persistence +
  sops ordering. ← prototype task, in flight.

**Phase 2 — physical enablers (one maintenance window, after resilver):**
- Install the 2× PM863a; create `rpool2` mirror (bigger ESPs ≥1 G on both).
- Flip VT-d on in BIOS (+`intel_iommu=on` later; harmless, enables the future
  HBA-passthrough upgrade path) — while the chassis is open anyway.
- Optional but recommended dry-run: apply impermanence to the *physical*
  system with root moved to rpool2 (blank-rollback) — this alone retires the
  spinner SPOF and burns in the persist list under production load, while the
  spinner remains the bootable rollback (DD7).

**Phase 3 — thin host + single guest (the big cutover, boot-menu-reversible):**
- Thin-host config (new `packages/hosts/beefcake-host.nix`): bridge, libvirt,
  smartd/disk-bays/IPMI, sshd, impermanent root on rpool2.
- Guest config = today's beefcake minus hardware.nix, plus virtio hardware,
  `/nix` in OS zvol, impermanence ON, same hostId/host-keys/secrets.
- Cut over: shut down bare-metal, boot thin host, guest imports zstorage,
  service MAC claims 192.168.0.9. Rollback = boot the spinner.
- Burn-in: mail/DNS/headscale/matrix/mDNS/exit-node all verified; perf checked
  (postgres, immich, CI runners; virtio-blk on spinners ≈ negligible vs seek
  latency, but measure).

**Phase 4 — blue/green machinery:**
- Second slot + validation network + fixture pipeline (blue snapshots → small
  state copies for green's gate).
- Cutover tool (`beefcake-cutover`): health gates, snapshot, NIC+disk move,
  automatic no-downgrade check (subsumes the devshell deploy wrapper for this
  host), one-command rollback. deploy-rs keeps deploying "into the active
  slot" for routine changes; risky bumps go through green.

**Phase 5 (optional, later):** VT-d HBA passthrough (needs host boot off a
PCIe NVMe adapter — hardware purchase), SR-IOV NIC slices, host-side
`zfs send` off-machine replication of the guest OS zvols.

---

## 5. Failure modes & operational notes

- **Host wedges:** guests die with it — same blast radius as today, but the
  host's closure is tiny/rarely-changing (that's the point). Host deploys
  follow the same no-downgrade/boot+reboot discipline; its update cadence is
  deliberately slow.
- **Guest wedges/panics:** host restarts it (`on_crash=restart`); host serial
  console (`virsh console`) replaces "drive to the LAN" for un-SSH-able states.
  This is a strict *improvement* on today's headscale-chicken-egg (host is
  reachable via LAN/its own tailscale regardless of guest VPN state).
- **Pool double-import:** structurally prevented (disk set attached to one
  domain; virtlockd; `zpool import` without `-f` refuses foreign hostid).
- **RAM:** guest ~200 G, host ~20 G + small capped ARC; guest runs its own big
  ARC. No swap today; consider zram/zswap in guest during Phase 3.
- **Monitoring split:** smartd/bays/IPMI/host-node-exporter on host (shipping
  to the guest's OpenObserve — accept the "monitoring target hosts its own
  sink" loop, alerts also go out via ntfy/Matrix which live in the guest;
  consider pointing host alerts at pebble's ntfy as the out-of-band channel).
- **k3s inside the guest:** unchanged; nested-virt not needed (no KVM use
  inside guest today).
- **Deploy targets:** `beefcake` (guest, as today) + new `beefcake-host` node
  in deploy-rs. The LAN-vs-VPN deploy caveat *relaxes* for the guest (host
  console is the recovery path) but stays for the host itself.

## 6. Open questions

1. ~~PM863a capacity~~ ANSWERED 2026-07-01: 240 G — and moot under Model B
   (SSD mirror carries only the host's slim root + ESPs).
2. ~~Persist-or-not `/var/cache`/`/var/log`~~ DECIDED 2026-07-01: persist
   `/var/cache/restic` (commented, dedicated dataset) and `/var/log`;
   journald already capped at 1G + shipped to OpenObserve.
3. ~~Validation fixtures~~ SUPERSEDED by Model B: validation uses ZFS clones
   of the full real state — strictly better than hand-picked fixtures. What
   remains is the per-service smoke-check registry (DD6.2, Daniel confirmed
   wanted).
4. libvirt+NixVirt vs microvm.nix vs hand-rolled qemu units — decide after the
   prototype. Model B tilts this toward **microvm.nix** (virtiofs shares +
   ro-store + volumes are literally its native vocabulary); requirements:
   zvol/share exclusivity, NIC hotmove or fast stop/start, serial console,
   autostart-active-slot marker on host /persist.
   Evaluated and rejected for the *slots* (2026-07-01): Firecracker (no
   PCI/vfio ever → kills the Phase-5 HBA path; no virtiofs; direct-kernel
   boot only), Ignite (archived), smolvm (libkrun; no raw block devices, no
   tap, no vfio), zeroboot (CoW-forked AI sandboxes, not pet VMs), Incus
   (qemu underneath — no gain; stateful daemon fights declarativeness).
   Still open for the *validation tier only*: cloud-hypervisor via
   microvm.nix — direct-kernel-boot the candidate toplevel with the host
   store shared read-only for a seconds-fast "does this generation start"
   gate, no OS-zvol build needed. VM boot time is irrelevant for the real
   slots anyway: green's clock is dominated by pool import + ~80 services.
5. Does anything on the LAN hard-code beefcake's *MAC* (router reservation
   aside)? (Wake-on-LAN, unifi fixed-IP by MAC, etc.)
6. IPv6: today's GUA is SLAAC on eno1; service MAC keeps EUI-64 stable enough,
   but verify AAAA records / firewall assumptions.

## 7. Prototype plan (dragon)

- **P1 `impermanence-vm`:** disko-built qemu image: ZFS root + `@blank`
  rollback via **systemd-initrd service**, `/persist` dataset
  (`neededForBoot`), impermanence module, sops-nix keyed from persisted host
  key, postgres + a DynamicUser service. Boot → seed state → reboot → assert:
  root actually rolled back, state + secrets + machine-id survived.
  Also delivered as a `nixosTest` for CI-able regression checking.
- **P2 `blue-green-handoff`:** two "slot" guests + file-backed "physical
  disks" on dragon; guest A creates a pool + writes state; cutover script
  stops A, attaches disks to B (same config, newer closure), B imports and
  serves the same state; then rollback. Plus a validation boot of B with no
  disks + fixture state. Measures the cutover wall-clock.
- **P3 `modelb-storage` (added after the 2026-07-01 DD2 revision):** prove
  Model B's storage primitives on one ZFS node: postgres with dataDir on an
  ext4-on-zvol; snapshot + clone of both a dataset and the zvol while
  postgres runs; a second postgres instance reads the *cloned* zvol
  (validation stand-in) and its writes provably never touch the origin;
  clone discard; zvol handoff origin→clone→origin. The virtiofs data plane
  (share mount, xattr/acl semantics) rides the established qemu/virtiofsd
  pattern and gets exercised in the Phase-3 integration on real hardware.

### Results (2026-07-01, all three passing on dragon)

Code: `prototypes/beefcake-impermanence/` (standalone flake, README inside).

- **P1a `checks.semantics` — PASS** (first run). Across a wiped root: sops
  decrypted unattended from the persisted age identity, postgres and
  DynamicUser (`/var/lib/private`) state survived, machine-id and ssh host
  key stayed stable, and an unpersisted `/root` file vanished. The feared
  sops-nix ordering problem did not materialize: `neededForBoot` on the
  persist mount is sufficient.
- **P1b `apps.rollback-demo` — PASS** (1m32s cached end-to-end). The
  systemd-initrd rollback unit works as designed. Gotchas harvested, all
  encoded as comments in `rollback-config.nix`:
  1. default flake-registry/NIX_PATH pins embed the whole nixpkgs tree in
     the image closure (blows fd limits + image size) — disable for images;
  2. `zpool import` in initrd uses `/dev/disk/by-id`, which is EMPTY for
     serial-less virtio disks → import hangs forever; use
     `boot.zfs.devNodes = "/dev/disk/by-path"` or assign disk serials —
     **this applies to the production guest's 12 virtio disks too**;
  3. image-built pools need `forceImportRoot` on first boot (foreign
     hostid); the blue/green handoff itself does not (shared hostId + clean
     export);
  4. the rollback unit needs `requires` (not just `after`) on the import
     unit.
- **P4 `lite/` — beefcake-lite PASS (2026-07-02): the REAL config runs in a
  VM.** `extendModules` over the actual `nixosConfigurations.beefcake`
  (dummy sops via generated format-plausible secrets, zstorage mounts →
  plain dirs, minecraft + immich-ML cut, egress-cut usernet): **54+
  services running in 24 G** (4 G actually used), boots to ssh in ~40 s.
  After empty-state shims (self-signed kanidm cert, writable tuwunel dirs,
  postgres ensure*), the only failures are structural-by-design:
  external-egress (dns-updater, tailscale, github-mirror, wyoming model
  download), dummy-creds (heisenbridge, matrix-hookshot), no-hardware
  (smartd — class H anyway), missing local-only image (hearth). ZERO
  unexplained failures — and tuwunel's RocksDB runs happily, partial
  class-Z evidence. sops-nix's build-time manifest validation doubles as a
  free "dummy secrets match the config's secret shape" regression gate.
  This IS the production validation tier, demonstrated end-to-end.
- **P2 `checks.handoff` — PASS.** Clean blue → green → blue pool handoff
  with postgres state continuity, plus green's no-pool validation boot.
  Gotcha: units whose `ReadWritePaths` live on the handed-off pool need
  `ConditionPathExists` (or equivalent) so boot-time auto-start skips
  instead of crash-looping into the start limit before the pool arrives —
  the production cutover tool must account for every such unit.
