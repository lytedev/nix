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
`>= 400` or fails to fetch, it fires **both** channels: an email via val.town's
`std/email` (a durable record) and a push to [ntfy.sh](https://ntfy.sh) (the
reliable alert).

This is the **dead-man's-switch for total beefcake outage**, and the only tier
that runs entirely off beefcake end to end. Detection exercises the full public
path (DNS → internet → Caddy → service), so it catches "beefcake / Caddy is
entirely down" — which Tier 1 and Tier 2 cannot, since they run on beefcake. The
**ntfy** leg is what makes the notification external too: a hosted push service
reached with one `fetch` and read by a phone app, so the alert arrives with
**no** beefcake dependency.

> **Why ntfy is the leg that matters.** `std/email` with no `to:` field delivers
> to the val.town account owner's registered address; if that is a `@lyte.dev`
> mailbox on Stalwart, the email queues at the VPS relay and is unreadable until
> beefcake returns (see [email-architecture.md](./email-architecture.md)) — i.e.
> you'd only see it _after_ recovery. The Tier-1 Matrix/hookshot path is _also_
> on beefcake (tuwunel), so it is likewise dead in a full outage. The email leg
> is kept as a backup/record, but only the ntfy push reliably reaches you during
> a genuine beefcake-down.

**Setup (one-time):**

1. Install the ntfy app (Android/iOS) or use the web app.
2. Prefer a **reserved** topic on a free ntfy.sh account (Access → reserve a
   topic → generate an access token) so the topic requires auth. A public topic
   is readable/writable by anyone who guesses its name.
3. In the val (Settings → Environment Variables) set `NTFY_URL` to the full
   topic URL (`https://ntfy.sh/<topic>`) and `NTFY_TOKEN` if reserved. The topic
   is intentionally **not** committed here; the same URL is stored in sops as
   `ntfy-sh-topic-url` for a future beefcake/pebble backup watcher.
4. Subscribe the phone to that topic (with the token if reserved) and test by
   running the val once.

Currently monitored: `files`, `mail`, `git`, `matrix`, `openobserve`
(`.lyte.dev`). These all sit behind Caddy, so they mainly catch a total outage;
a specific backend failing while Caddy stays up shows as a `502` and is caught
too, but per-service health while the box is up is really Tier 1's job. DNS and
the VPN aren't HTTP-checkable this way. It lives on val.town, not in this flake;
the snapshot here is for the record and drifts if the val is edited.

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

- **beefcake-down is covered by the Tier 0 val.town + ntfy.sh watcher**, which
  is external end to end. Remaining follow-ups: it depends on a single third
  party (val.town) — consider a same-tailnet backup watcher (pebble/rascal) or a
  second cron elsewhere so the dead-man's-switch isn't solely on val.town; and
  the watcher lives on val.town, so this repo can only snapshot it, not enforce
  it.
- **Dead code cleanup.** `prometheus.nix` / `grafana.nix` are unimported; a
  separate PR should delete them to remove the "we have Prometheus" illusion.
- **Shared notifier dedup.** `matrix-alerts.nix` intentionally duplicates the
  small hookshot-poster shell from `disk-alerts.nix` rather than refactoring a
  shared `lyte.matrix-notify` helper in the same change (repo policy: features
  don't refactor shared code inline). Extracting that helper is a fast-follow.
