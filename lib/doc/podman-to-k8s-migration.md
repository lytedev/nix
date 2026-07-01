# podman → k3s migration plan (beefcake)

A pragmatic, opinionated plan for moving beefcake's podman/`oci-containers`
workloads into the k3s cluster over time. This is a **recommendation with
sequencing**, not a mandate to rewrite everything — several workloads should
*stay* on podman indefinitely, and that's the right call.

Read alongside:

- `lib/doc/k8s-service-example.yaml` — the canonical Deployment+Service+Ingress
  pattern for a `*.k.lyte.dev` app.
- `lib/doc/k8s-networkpolicy-template.yaml` — the per-namespace default-deny +
  allow baseline.
- `packages/hosts/beefcake/k3s.nix` — cluster wiring (loopback NodePort, PSA,
  edge separation).

## TL;DR

- **Thumbs up, but slowly and selectively.** k3s is the right home for *simple,
  stateless-ish, HTTP* services that today sit behind caddy. Migrating them
  buys uniform deploys, NetworkPolicy isolation, PodSecurity, and one ingress
  story.
- **On a single node, almost everything *can* run in k8s — the real axis is
  "uniformity gained vs. isolation given up," not "possible vs. impossible."**
  The k8s node *is* the host, so a `hostNetwork` pod has identical LAN/loopback
  access to today's `--network=host` container. The host-network / raw-TCP
  workloads (music-assistant, mmrelay, game servers) therefore *can* migrate —
  but only into a **PSA-`privileged`, NetworkPolicy-exempt namespace**, so they
  get the uniform-workflow benefit and **none** of the hardening benefit. That's
  a legitimate trade if one workflow (everything a manifest, visible in k9s) is
  the goal; just go in eyes-open.
- **A few should stay off k8s on principle, not capability.** openobserve is the
  observability *sink* — putting the tool you'd use to debug a wedged cluster
  *inside* that cluster is a circular dependency. Keep infra-tier services on the
  host.
- **Prove the pattern once, end-to-end, on a low-stakes HTTP app first**
  (bulwark), including sops→Secret and hostPath storage. Then batch the rest.

## What "good in k8s" looks like here

The cluster is deliberately constrained (see `k3s.nix`):

- **caddy is the sole edge on :80/:443.** Apps are reached *only* as
  `https://<app>.k.lyte.dev` → caddy → traefik's loopback NodePort 30081 →
  ClusterIP Service → pods. So a migratable app must speak **HTTP** behind an
  Ingress.
- **No ServiceLB, and kube-proxy NodePorts are pinned to loopback**
  (`--kube-proxy-arg=nodeport-addresses=127.0.0.0/8`). So *NodePort/LoadBalancer*
  services can't reach the LAN — that's the outage guard for the `:443` edge.
  This is **not** the same as "no raw-TCP path exists"; see the escape-hatch
  section below (`hostPort` bypasses kube-proxy entirely, and caddy-l4 preserves
  the single-edge story).
- **Single node.** hostPath on `/storage` (ZFS, already in the restic backup
  set) is the simplest durable storage. PVCs work but add indirection with no
  payoff at one node (see Storage below).

So the migration sweet spot is: **HTTP, single-replica, state that fits a
hostPath, secrets that fit a mounted file or a small Secret.** Everything else is
possible but pays for it (privileged namespace, hostPort, no isolation).

## Exposing a raw/LAN TCP port (the NodePort exception)

`nodeport-addresses=127.0.0.0/8` is a **node-global** kube-proxy setting — there
is no per-service knob to bind one NodePort on the LAN while the rest stay
loopback. **Do not** flip it globally (that re-exposes *every* NodePort on the
LAN and defeats the design). To let a *specific* workload (a game server, any
raw-TCP service) take a LAN/WAN port, pick one of:

1. **`hostPort` on the pod (recommended for the one-off).** A `hostPort` is a
   CNI/portmap binding — k3s bundles the portmap plugin, so it works out of the
   box — and it **bypasses kube-proxy's `nodeport-addresses` entirely**. It
   binds the port on the node directly, defaulting to all interfaces; pin it with
   `hostIP: 192.168.0.9` for LAN-only. Crucially it does **not** touch `:80/:443`,
   so it does *not* re-create the ServiceLB/`:443` outage hazard. Caveats:
   `hostPort` is **baseline-PSA-forbidden**, so the workload's namespace must be
   labeled `pod-security.kubernetes.io/enforce: privileged`; and the pod is pinned
   to the node (fine at one node). This is the surgical, per-workload exception.
2. **caddy-l4 stream proxy (keeps caddy the sole edge).** Keep the service a
   *loopback* NodePort/ClusterIP and have caddy — built with the
   [`caddy-l4`](https://github.com/mholt/caddy-l4) layer-4 plugin — listen on
   `192.168.0.9:<port>` and TCP-proxy to `127.0.0.1:<loopback-nodeport>`. This
   preserves the "everything LAN-facing goes through caddy" invariant for TCP
   too, and the service keeps loopback-only exposure. Cost: a custom caddy build
   with the plugin. Best when you want the edge story to stay uniform.

Rule of thumb: one-off game server → `hostPort`; a class of TCP services you want
funnelled through the one edge → caddy-l4.

## Workload triage

These verdicts reflect Daniel's calls (2026-07).

| Workload | Shape today | Verdict | Notes |
|---|---|---|---|
| **bulwark** (webmail) | 1 container, sops env, loopback `:3000`, caddy `reverse_proxy` | ✅ **First move (pattern-prover)** | Plain HTTP web client. Cleanest end-to-end proof of namespace+netpol / sops→secret / hostPath / ingress. |
| **hearth** | locally-built `localhost/hearth:latest`, HTTP | ✅ **Early** | Same HTTP pattern, plus exercises the `k3s ctr images import` local-image path (see below). |
| **matrix bridges** (`mautrix-*`, heisenbridge, hookshot) + **jmap-matrix-notify** | app containers ↔ tuwunel, sqlite/registration on disk, sops registration files | ✅ **Batch — move *with* tuwunel** | Appservice traffic is **bidirectional** (bridges dial tuwunel *and* tuwunel pushes to each bridge). If tuwunel stays on the host while bridges become pods, the host must reach ClusterIPs — the classic split-appservice pain. So migrate tuwunel **and** all bridges together as one unit, or leave the whole set on the host. Don't straddle the boundary. |
| **music-assistant** | `--network=host` for **Cast/AirPlay mDNS**, hostPath `/data` | ✅ **OK — hostNetwork, privileged ns** | Single node ⇒ a `hostNetwork: true` pod sees LAN multicast exactly as today's container. Needs a `pod-security.kubernetes.io/enforce: privileged` namespace and gets **no netpol isolation**. "podman with more YAML"; fine if uniformity is the goal. |
| **mmrelay** | `--network=host`, talks to **meshtasticd** on `localhost:4403` + mosquitto | ✅ **OK — hostNetwork, privileged ns** | Same as MA: `hostNetwork` pod reaches host `localhost:4403`. Privileged namespace, no isolation. (Alternative: bind meshtasticd to the cni bridge and skip hostNetwork — more moving parts; hostNetwork is simpler.) |
| **minecraft / game servers** (jonland / prom2 / `minecraft-server-containers`) | `itzg/minecraft-server`, **raw TCP :25565**, large world state | ✅ **OK — `hostPort`, privileged ns** | Expose via pod `hostPort: 25565` (bypasses the loopback NodePort pin; does **not** threaten the `:443` edge). Baseline forbids `hostPort` ⇒ privileged namespace. Big stateful world on hostPath `/storage`. A pets workload with modest k8s payoff, but feasible. See the NodePort-exception section. |
| **openobserve** | 1 container, sops env, hostPath vol, loopback `:5080`, otel sink | ❌ **Stay on host** | It's the observability **sink** (host otel-collector ships to `127.0.0.1:5080`). Running the tool you'd use to debug a wedged cluster *inside* that cluster is a circular dependency. Infra-tier, low churn ⇒ little uniformity payoff. |
| **actual** (actualbudget) | 1 container, hostPath data, HTTP | — **Being deleted** | Dropped from the plan (Daniel is removing it). |
| **happy** | retired self-hosted happy-coder server | 🔥 **Deleted** | Unused + scary; already retired since 2026-06. `happy.nix` removed in this PR (config only — see the on-disk/sops cleanup list). |

Legend: ✅ migrate · ❌ keep off k8s (principle) · 🔥 delete · — n/a.

**On the ✅-privileged-namespace ones (MA, mmrelay, game servers):** put each in
its own namespace labeled `pod-security.kubernetes.io/enforce: privileged` so it
opts out of the cluster's `baseline` default (the PSA config in `k3s.nix` is only
a *default*; per-namespace labels override it). They won't get NetworkPolicy
isolation either (hostNetwork bypasses netpol). The rest of the cluster keeps the
hardened baseline — the exceptions are contained to their own namespaces.

## The mechanics (how each concern moves)

### Images

- **Public images** (`docker.io/…`, `ghcr.io/…`, `public.ecr.aws/…`) just pull —
  put the ref straight in the Deployment.
- **Locally-built images** (e.g. `localhost/hearth:latest`) are invisible to
  k3s's containerd. Import into containerd and pin the pull policy so k8s doesn't
  try to re-pull:

  ```bash
  podman save localhost/hearth:latest | sudo k3s ctr images import -
  # in the Deployment: imagePullPolicy: Never   (or IfNotPresent)
  ```

  To make this declarative, add a `systemd` oneshot on beefcake (after the build,
  before/independent of k3s) that re-runs the `save | k3s ctr images import -`
  pipeline whenever the image changes — mirrors how the image is built today.

### Secrets (sops → k8s)

Do **not** paste secrets into manifests (they'd sit plaintext in-repo and in
etcd). Two good options, both keeping sops as the source of truth:

1. **hostPath-mount the sops-decrypted file (preferred at single-node).** sops-nix
   already decrypts secrets to `config.sops.secrets.<name>.path` on the host.
   Mount that path read-only into the pod as a file/env-file via a `hostPath`
   volume. No secret is copied into etcd; rotation stays a sops/deploy concern.
2. **kubectl-create-secret oneshot.** A `systemd` oneshot (after `k3s`,
   idempotent `kubectl create secret generic … --from-env-file=<sops path> -o yaml
   --dry-run=client | kubectl apply -f -`) materialises a real k8s `Secret` from
   the sops file. Use this when a workload expects a native `Secret` (envFrom /
   projected volume) rather than a file.

Skip External-Secrets-Operator / sops-operator — overkill for one node.

### Storage

- **hostPath on `/storage` (recommended).** Single node, ZFS, and *already in the
  restic backup set* (`services.restic.commonPaths`). A `hostPath` volume to e.g.
  `/storage/<app>` is the least-surprise, backup-covered choice. Keep the same
  on-disk layout the podman workload used so data moves by a path rename.
- **PVC via local-path-provisioner** works but writes under the k3s dataDir
  (`/storage/k3s/storage/…` given our custom `--data-dir`, *not* the upstream
  `/var/lib/rancher/k3s/storage`). That's an extra indirection and a backup path
  you'd have to remember to cover. Only reach for PVCs if/when multi-node.

### Networking / security (applied per app)

- Give each app its **own namespace** and drop in the default-deny baseline from
  `k8s-networkpolicy-template.yaml` (default-deny-ingress + allow-from-traefik +
  allow-dns). Do this from the start so isolation is the default, not a retrofit.
- The cluster-wide **PodSecurity** default is `baseline` enforce (see `k3s.nix`).
  HTTP apps (bulwark, hearth, bridges) must be baseline-clean: no `privileged`,
  no `hostNetwork`, no `hostPort` (both are baseline-forbidden). A `hostPath`
  *volume* for data is fine under baseline. The host-network / hostPort workloads
  (MA, mmrelay, game servers) instead go in a namespace labeled
  `pod-security.kubernetes.io/enforce: privileged`, opting out of the default —
  contained to their own namespace, no netpol isolation.

### Reaching host services from pods (postgres, redis, …)

Pods are on the flannel net (`10.42.0.0/16`), reached at the host via the `cni0`
bridge (`10.42.0.1`) — **not** loopback. Today postgres/redis bind loopback only
(postgres was just tightened from `0.0.0.0` to `localhost` — see
`packages/hosts/beefcake/postgres.nix`). So the FIRST migrated app that needs a
host-resident datastore must:

1. Add the bridge IP to the service's `listen_addresses`/`bind`
   (e.g. postgres `settings.listen_addresses = "localhost,10.42.0.1"`).
2. Add a **scoped** `pg_hba` line for the pod CIDR (`host <db> <user> 10.42.0.0/16
   <method>`) — scoped to the CIDR, never `0.0.0.0/0`, never `trust` for a
   non-loopback source (use `scram-sha-256`).
3. Consider whether the datastore should itself move into the cluster instead.

Prefer, where practical, to move an app *together with* its datastore (run
postgres/redis as in-cluster StatefulSets) so nothing has to punch the host
loopback boundary — but that's a later-stage decision, not a first move.

## Recommended order

1. **(this PR) Baseline the cluster.** PodSecurity `baseline` default + the
   NetworkPolicy template + postgres loopback bind + delete the retired `happy`.
   No workloads move yet.
2. **Remove the stale test junk.** Delete the 169-day `default/echo-server`
   Deployment/Service and the `whoami` example once real apps land (runtime
   state — Daniel deletes; see the flag in the PR). Keeps `default` empty so it
   can stay locked down.
3. **Prove the pattern on `bulwark`** (first HTTP move). Full loop: namespace +
   netpol, Deployment+Service+Ingress, sops secret via hostPath mount, hostPath
   data on `/storage`, cut caddy to proxy the ingress. Confirm live, then delete
   the podman unit.
4. **`hearth`** — same pattern, plus the local-image import path (containerd).
5. **Matrix + tuwunel batch** (`mautrix-*` + heisenbridge + hookshot +
   jmap-matrix-notify **and** tuwunel) — as ONE coordinated change after
   secrets+storage are proven, because appservice traffic is bidirectional and
   must not straddle the host/cluster boundary. Or leave the whole set on the
   host.
6. **Host-network / game-server workloads, if/when you want the uniform
   workflow:** `music-assistant`, `mmrelay`, `minecraft` — each into its own
   `privileged`-labeled namespace (hostNetwork / hostPort), no netpol. Lowest
   priority; they gain workflow uniformity, not hardening.
7. **Stay off k8s:** `openobserve` (observability sink — circular dep).

## Anti-goals / guardrails

- **Never re-enable ServiceLB or create a LoadBalancer service, and never widen
  `nodeport-addresses` off loopback.** That is the specific outage guard for the
  `:80/:443` edge. Note this does *not* forbid a pod `hostPort` on a distinct
  high port (e.g. game-server `:25565`) — that bypasses kube-proxy and never
  touches the web edge (see the NodePort-exception section). The line is
  "nothing may contend for the caddy edge," not "no host ports ever."
- Don't fold "migrate app X" and "refactor the shared k8s module" into one
  change. Extract shared manifest helpers as their own step.
- Don't materialise secrets into the repo or into etcd when a hostPath mount of
  the existing sops file will do.
