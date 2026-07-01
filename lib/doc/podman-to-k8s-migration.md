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
- **Some workloads should never move.** Anything that needs `--network=host`
  (mDNS/Cast discovery), local hardware / a serial mesh node, or a raw non-HTTP
  TCP port is *harder in k8s than in podman* and gains nothing. Keep them on
  podman.
- **Prove the pattern once, end-to-end, on a low-stakes app first** (openobserve
  or actual), including sops→Secret and hostPath storage. Then batch the rest.

## What "good in k8s" looks like here

The cluster is deliberately constrained (see `k3s.nix`):

- **caddy is the sole edge on :80/:443.** Apps are reached *only* as
  `https://<app>.k.lyte.dev` → caddy → traefik's loopback NodePort 30081 →
  ClusterIP Service → pods. So a migratable app must speak **HTTP** behind an
  Ingress.
- **No ServiceLB, NodePorts are loopback-only.** There is *no* way to expose a
  raw TCP port to the LAN from the cluster. A workload that needs a public
  non-HTTP port (game server, etc.) cannot use this cluster without reintroducing
  the exact host-port-binding capability the edge-separation design removed.
- **Single node.** hostPath on `/storage` (ZFS, already in the restic backup
  set) is the simplest durable storage. PVCs work but add indirection with no
  payoff at one node (see Storage below).

So the migration sweet spot is: **HTTP, single-replica, state that fits a
hostPath, secrets that fit a mounted file or a small Secret.**

## Workload triage

| Workload | Shape today | Verdict | Notes |
|---|---|---|---|
| **openobserve** | 1 container, sops env, hostPath vol, loopback `:5080`, caddy-proxied | ✅ **Early candidate** | Cleanest first move — already HTTP-behind-caddy. Becomes an Ingress app. |
| **actual** (actualbudget) | 1 container, hostPath data, HTTP | ✅ **Early candidate** | Small, self-contained, low blast radius. Good pattern-prover. |
| **bulwark** (webmail) | 1 container, sops env, loopback `:3000`, caddy `reverse_proxy` | ✅ **Good, after pattern proven** | HTTP; coupled to the mail stack but only as a client. |
| **hearth** | locally-built `localhost/hearth:latest`, HTTP | ✅ **Good, needs image import** | Exercises the `k3s ctr images import` local-image path (see below). |
| **matrix bridges** (`mautrix-*`, heisenbridge, hookshot) | app containers → tuwunel, sqlite/registration on disk, sops registration files | 🟡 **Medium — batch later** | All share a shape (talk to tuwunel, need a sops `registration.yaml` + a sqlite/postgres store). Migrate as *one* batch once secrets+storage are solved, not one-by-one. Keep **tuwunel** (the homeserver) itself on the host until last, or leave it. |
| **jmap-matrix-notify** | small notifier | 🟡 **Medium** | Fine to move with the bridge batch; low value alone. |
| **music-assistant** | `--network=host` for **Cast/AirPlay mDNS**, hostPath `/data` | ❌ **Stay podman** | mDNS discovery needs host network. `hostNetwork: true` pods violate baseline PSA *and* defeat NetworkPolicy — you'd be fighting the cluster's whole security model for zero gain. |
| **mmrelay** | `--network=host`, talks to **meshtasticd** on `localhost:4403` + mosquitto, mesh hardware | ❌ **Stay podman** | Host-network + local hardware/daemon coupling. No benefit in k8s. |
| **minecraft** (jonland / prom2 / `minecraft-server-containers`) | `itzg/minecraft-server`, **raw TCP :25565**, large world state | ❌ **Stay podman** | Players connect over a raw public TCP port. The cluster has no LAN-facing port path by design (no ServiceLB, loopback NodePorts). Putting it in k8s means re-adding host-port binding — the one thing the 2026-06 edge-separation outage guard forbids. |
| **happy** | locally-built image, `--network=host`, postgres+redis+garage+S3 | ❌ **Stay podman (for now)** | Multi-service, host-network, tightly coupled to on-host garage/redis. Migrate only if it's ever rebuilt as a clean HTTP service; not worth it today. |

Legend: ✅ migrate early · 🟡 migrate later / as a batch · ❌ keep on podman.

## The mechanics (how each concern moves)

### Images

- **Public images** (`docker.io/…`, `ghcr.io/…`, `public.ecr.aws/…`) just pull —
  put the ref straight in the Deployment.
- **Locally-built images** (`localhost/hearth:latest`, `localhost/happy-server`)
  are invisible to k3s's containerd. Import into containerd and pin the pull
  policy so k8s doesn't try to re-pull:

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
  Migrated apps must be baseline-clean: no `privileged`, no `hostNetwork`, no
  `hostPath` for *device* access (a hostPath *volume* for data is allowed under
  baseline; host **path types** like device files are what baseline restricts —
  validate per app). This is exactly why the `--network=host` workloads are ❌.

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
   NetworkPolicy template + postgres loopback bind. No workloads move yet.
2. **Remove the stale test junk.** Delete the 169-day `default/echo-server`
   Deployment/Service and the `whoami` example once real apps land (runtime
   state — Daniel deletes; see the flag in the PR). Keeps `default` empty so it
   can stay locked down.
3. **Prove the pattern on ONE low-stakes app: `openobserve` (or `actual`).**
   Full loop: namespace + netpol, Deployment+Service+Ingress, sops secret via
   hostPath mount, hostPath data on `/storage`, cut caddy to proxy the ingress.
   Confirm live, then delete the podman unit.
4. **`hearth`** — same pattern, plus the local-image import path (containerd).
5. **`bulwark`** — same HTTP pattern once 3–4 are boring.
6. **Matrix bridge batch** (`mautrix-*` + heisenbridge + hookshot +
   jmap-matrix-notify) — as ONE coordinated change after secrets+storage are
   proven, because they share a shape. Decide separately whether tuwunel itself
   moves (recommend: last, or never).
7. **Leave on podman, permanently:** `music-assistant`, `mmrelay`, `minecraft`,
   `happy`. Revisit only if a workload is fundamentally rearchitected.

## Anti-goals / guardrails

- Don't reintroduce host-port binding (no `hostPort`, no ServiceLB, no
  LoadBalancer) to fit a workload — that's the outage guard. If an app can't be
  reached as HTTP-behind-traefik, it stays on podman.
- Don't fold "migrate app X" and "refactor the shared k8s module" into one
  change. Extract shared manifest helpers as their own step.
- Don't materialise secrets into the repo or into etcd when a hostPath mount of
  the existing sops file will do.
