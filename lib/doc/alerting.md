# Alerting Architecture

_Written 2026-07 as part of the security-audit observability follow-up (M6)._

## The question this answers

> "I THINK we have alerting in OpenObserve, but that isn't clear from the repo —
> can we encode it into the repo somehow?"

Short answer: metrics and logs are collected, but **almost no alerting is
encoded in this repo**, and any alerting that exists lives in OpenObserve's own
database/UI (not version-controlled). This document records what is actually
running and the declarative starter this repo now ships.

## What is actually running (discovered live, 2026-07)

### Telemetry collection — OpenTelemetry Collector → OpenObserve

The live metrics/logs pipeline is **not** classic Prometheus. Every
`lyte.server.enable = true` host runs a single
[OpenTelemetry Collector](../modules/nixos/server.nix) that:

- scrapes `hostmetrics` (cpu/disk/filesystem/load/memory/network/paging/process),
- scrapes the `node_exporter` (systemd unit states, on `127.0.0.1:9100`),
- ships `journald` + `filelog` logs,

and exports all of it to **OpenObserve** (`otlphttp/openobserve`). On beefcake
the collector additionally scrapes the zfs and postgres exporters
([opentelemetry-collector.nix](../../packages/hosts/beefcake/opentelemetry-collector.nix)).

OpenObserve itself runs as a container on beefcake, reverse-proxied at
`https://openobserve.h.lyte.dev`, storing its data under `/storage/openobserve`
on the `zstorage` pool ([openobserve.nix](../../packages/hosts/beefcake/openobserve.nix)).

### Dead code — classic Prometheus + Grafana

`packages/hosts/beefcake/prometheus.nix` (a full `services.prometheus` server
with `remoteWrite` to OpenObserve) and `grafana.nix` **are not imported** by
`beefcake.nix` — Grafana is commented out ("replaced by OpenObserve") and
`prometheus.nix` is not in the module list at all. There is therefore **no
Prometheus server, no rule-evaluation engine, and no Alertmanager running**.
The only reason a node_exporter answers on `:9100` is that the OTel collector
enables it purely as a scrape source.

This is why adding Prometheus + Alertmanager was rejected as the approach: it
would stand up a second, parallel metrics stack that Daniel deliberately
removed.

### The only alerting encoded in the repo (before this change)

[disk-alerts.nix](../../packages/hosts/beefcake/disk-alerts.nix) wires `smartd`
(SMART pre-failure) and the ZFS Event Daemon (pool faults / DEGRADED vdevs /
resilver errors) to a matrix-hookshot generic webhook. That is host-direct and
deliberately does **not** route through OpenObserve, because OO stores its data
on the very pool a disk alert is about.

There is no Prometheus Alertmanager and no k3s audit log (`grep -riE
'alertmanager|alerting|rule'` across the modules finds nothing but this work).

### OpenObserve alerts (could not be enumerated remotely)

OpenObserve _does_ support alerts, alert templates, and destinations, stored in
its own DB and configured in its UI — exactly the "not clear from the repo"
gap. Its API confirms the endpoints exist:

- `GET /api/default/alerts`, `GET /api/default/alerts/templates`,
  `GET /api/default/alerts/destinations` (all returned `401` unauthenticated).

Enumerating the actual alert definitions requires the OpenObserve root
credentials (`openobserve.env` in sops). That live read was blocked during this
work, so **whether any OO alerts currently exist is unconfirmed** — run the
export helper below (as Daniel, who can auth) to find out and capture them.

## The declarative starter this repo now ships

The design follows the boundary that `disk-alerts.nix` already established:
**failure classes that mean "the box or its storage is in trouble" must not
depend on OpenObserve** (which lives on that same box/pool); everything else
can go through the metrics/log stack (OO). Above both of those sits an
off-site watcher, because nothing running _on_ beefcake can report that
beefcake itself is down.

### Tier 0 — external (off-site) uptime monitoring

A [val.town](https://www.val.town) cron
(`lytedev/SimpleSiteUptimeMonitor`, source snapshot:
[external-uptime-monitor.tsx](./external-uptime-monitor.tsx)) runs _off_
beefcake and HTTP-GETs a list of public endpoints on a schedule; if any returns
`>= 400` or fails to fetch, it emails via val.town's own `std/email`.

This is the **dead-man's-switch for total beefcake outage**. It is the only
tier whose detection _and_ notification paths are both external:

- It exercises the full public path (DNS → internet → Caddy → service), so it
  catches "beefcake / Caddy is entirely down" — which Tier 1 and Tier 2 cannot,
  since they run on beefcake.
- Its notification does **not** route through beefcake's Stalwart: val.town
  sends the alert email from its own infrastructure, so it still arrives when
  beefcake (and therefore mail) is down.

Currently monitored: `files.lyte.dev`, `openobserve.h.lyte.dev`. Because it
only checks those two Caddy vhosts, it detects a full outage but **not** a
single service failing behind a healthy Caddy (that is Tier 1's job). Worth
expanding the list to the other externally-reachable criticals — `mail.lyte.dev`
(Stalwart), `git.lyte.dev` (Forgejo), the Matrix/VPN endpoints — so a partial
outage also pages. It lives on val.town, not in this flake; the snapshot here
is for the record and drifts if the val is edited.

### Tier 1 — host-direct systemd alerts (OO-independent)

[matrix-alerts.nix](../../packages/hosts/beefcake/matrix-alerts.nix) posts to
the same matrix-hookshot webhook the disk alerts use
(`disk-alert-webhook-url` in sops — no new secret, works on deploy). It adds:

- **`OnFailure → Matrix`** on the critical units (caddy, stalwart, forgejo,
  tuwunel, knot, headscale): if any crashes/fails, systemd fires a notifier
  with the unit's status + recent journal lines. This needs no metrics stack —
  it is the most robust "service down" signal available.
- **Disk usage ≥ 90%** — an hourly timer scans local filesystems and posts if
  any is over threshold. Host-direct on purpose (a disk-full alert should not
  depend on OO, which is on that disk).

### Tier 2 — OpenObserve alerts, captured declaratively

[openobserve-alerts/](../../packages/hosts/beefcake/openobserve-alerts/)
provides the mechanism to pull OO's own alerts into version control and enforce
them, answering the literal question ("encode it into the repo"):

- **`openobserve-alerts-export`** (installed to `$PATH` on beefcake): dumps the
  live alerts + templates + destinations to JSON so they can be committed under
  `definitions/`. Read-only; safe to run any time.
- **A reconcile oneshot** (opt-in, `lyte.openobserveAlerts.enable`, default
  **off**): re-applies the committed JSON to OO's API so the repo is the source
  of truth. Kept off by default because it mutates live OO state and could not
  be tested during this work; enable it after exporting + committing real
  definitions and confirming the API against the running OO version. See that
  directory's README for the exact endpoints.

The metrics/log-based alerts that belong in Tier 2 (they need the metrics/logs
OO already holds) are: **host/node down for remote hosts** (a host-direct
alert can't detect its own host being down — see the follow-up below),
**SSH auth-failure spikes** (a log-pattern query over the journald logs OO
ingests), and any threshold alerts on CPU/memory/zfs/postgres.

## Known gaps / follow-ups

- **beefcake-down is covered externally, not by this flake.** Tier 1 and OO
  both run _on_ beefcake, so neither can alert that beefcake itself is
  unreachable. The Tier 0 val.town watcher fills that gap. Follow-up: broaden
  its endpoint list beyond `files`/`openobserve` so a single-service outage
  behind a healthy Caddy also pages, and consider a same-tailnet backup watcher
  (pebble/rascal) so the dead-man's-switch isn't solely on a third-party.
- **Dead code cleanup.** `prometheus.nix` / `grafana.nix` are unimported; a
  separate PR should delete them to remove the "we have Prometheus" illusion.
- **Shared notifier dedup.** `matrix-alerts.nix` intentionally duplicates the
  small hookshot-poster shell from `disk-alerts.nix` rather than refactoring a
  shared `lyte.matrix-notify` helper in the same change (repo policy: features
  don't refactor shared code inline). Extracting that helper is a fast-follow.
