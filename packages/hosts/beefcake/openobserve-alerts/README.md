# OpenObserve alerts — declarative capture

OpenObserve keeps its alerts, alert templates, and destinations in its own
database and configures them through the UI, so they are invisible to this
repo. This directory captures them into version control.

See `../../../../lib/doc/alerting.md` for the overall alerting design and why
these OO alerts are the "Tier 2" (metrics/log-based) half of it.

## Export what exists now → commit it

The export helper is installed on beefcake. It reads the OpenObserve root
credentials from the `openobserve.env` sops secret, so run it as root:

```bash
sudo openobserve-alerts-export \
  /etc/nixos/packages/hosts/beefcake/openobserve-alerts/definitions
```

It writes (pretty-printed, key-sorted for stable diffs):

- `definitions/alerts.json`
- `definitions/alerts-templates.json`
- `definitions/alerts-destinations.json`

Review and commit them. That alone answers "encode our OO alerting into the
repo" — the current live alerts are now recorded and diffable.

## Enforce the repo as source of truth (opt-in)

`reconcile.py` PUTs the committed JSON back to OO (create-or-update), so drift
in the UI is corrected. It is **off by default** because it mutates live OO
state and was not testable when written. Enable it only after you have exported
+ committed real definitions and sanity-checked them against the running OO
version:

```nix
lyte.openobserveAlerts.enable = true;
```

That adds a `openobserve-alerts-reconcile` oneshot (on activation + hourly).

### API paths used (this OpenObserve version)

Confirmed from the OpenObserve router:

| Object       | List                              | Create/update                                   |
| ------------ | --------------------------------- | ----------------------------------------------- |
| alerts       | `GET /api/{org}/alerts`           | `PUT /api/{org}/{stream_name}/alerts/{name}`    |
| templates    | `GET /api/{org}/alerts/templates` | `PUT /api/{org}/alerts/templates/{name}`        |
| destinations | `GET /api/{org}/alerts/destinations` | `PUT /api/{org}/alerts/destinations/{name}`  |

If a future OO upgrade changes these paths, update `reconcile.py` and the
export helper together.

## Suggested starter alerts to create in OO (then export)

These belong here (not host-direct) because they need the metrics/logs OO
already holds:

- **host/node down (remote hosts)** — beefcake can't detect its own death, but
  it can alert when a _remote_ `lyte.server` host stops reporting metrics.
- **SSH auth-failure spikes** — a log query over the journald logs OO ingests
  (`sshd` "Failed password" / "Invalid user" rate).
- **CPU / memory / zfs / postgres thresholds** — from `hostmetrics` and the
  zfs/postgres exporters.

Create them in the OO UI, wire a destination to the Matrix hookshot webhook,
then re-run the export to capture them here.
