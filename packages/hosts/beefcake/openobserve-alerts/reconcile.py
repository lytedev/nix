#!/usr/bin/env python3
"""Reconcile OpenObserve alert objects from checked-in JSON into the live OO API.

Makes the repo the source of truth for OpenObserve's alert templates,
destinations, and alerts. Consumes exactly the files that
`openobserve-alerts-export` writes:

    alerts-templates.json      (array of template objects)
    alerts-destinations.json   (array of destination objects)
    alerts.json                (array of alert objects)

and PUTs each element (create-or-update) to the OO API. Order matters —
templates and destinations first, since alerts reference them.

API paths (confirmed against the OpenObserve router for this deployment):
    PUT /api/{org}/alerts/templates/{name}
    PUT /api/{org}/alerts/destinations/{name}
    PUT /api/{org}/{stream_name}/alerts/{name}

Env:
    DEFS_DIR      directory holding the three JSON files (required)
    OO_ENV_FILE   path to openobserve.env (ZO_ROOT_USER_EMAIL/PASSWORD); optional
                  if the creds are already in the environment
    OO_BASE       default http://127.0.0.1:5080
    OO_ORG        default "default"

This mutates live OpenObserve state, so the systemd unit that runs it is
opt-in (`lyte.openobserveAlerts.enable`, default off). Validate the exported
JSON against your running OO version before enabling.
"""

import base64
import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("OO_BASE", "http://127.0.0.1:5080")
ORG = os.environ.get("OO_ORG", "default")
DEFS_DIR = os.environ["DEFS_DIR"]


def log(msg):
    print(msg, flush=True)


def load_creds():
    email = os.environ.get("ZO_ROOT_USER_EMAIL")
    password = os.environ.get("ZO_ROOT_USER_PASSWORD")
    env_file = os.environ.get("OO_ENV_FILE")
    if (not email or not password) and env_file and os.path.isfile(env_file):
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if "=" not in line or line.startswith("#"):
                    continue
                k, v = line.split("=", 1)
                v = v.strip().strip('"').strip("'")
                if k == "ZO_ROOT_USER_EMAIL" and not email:
                    email = v
                elif k == "ZO_ROOT_USER_PASSWORD" and not password:
                    password = v
    if not email or not password:
        sys.exit("reconcile: no OpenObserve credentials (set OO_ENV_FILE or ZO_ROOT_USER_*)")
    token = base64.b64encode(f"{email}:{password}".encode()).decode()
    return f"Basic {token}"


def put(auth, path, obj):
    url = f"{BASE}/api/{ORG}/{path}"
    req = urllib.request.Request(
        url,
        data=json.dumps(obj).encode(),
        method="PUT",
        headers={"Authorization": auth, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.status


def load_array(name):
    path = os.path.join(DEFS_DIR, name)
    if not os.path.isfile(path):
        log(f"{name}: absent — skipping")
        return []
    with open(path) as f:
        data = json.load(f)
    # Exports may be a bare array or wrapped as {"list": [...]}.
    if isinstance(data, dict):
        data = data.get("list", [])
    return data


def apply(auth, name, path_for):
    ok = fail = 0
    for obj in load_array(name):
        try:
            path = path_for(obj)
        except KeyError as e:
            log(f"{name}: object missing {e} — skipping")
            fail += 1
            continue
        try:
            put(auth, path, obj)
            log(f"  applied {path}")
            ok += 1
        except urllib.error.HTTPError as e:
            body = e.read().decode(errors="replace")[:500]
            log(f"  FAILED {path}: HTTP {e.code} {body}")
            fail += 1
        except Exception as e:  # noqa: BLE001
            log(f"  FAILED {path}: {e!r}")
            fail += 1
    return ok, fail


def main():
    auth = load_creds()
    total_ok = total_fail = 0
    # templates + destinations before alerts (alerts reference them)
    for name, path_for in [
        ("alerts-templates.json", lambda o: f"alerts/templates/{o['name']}"),
        ("alerts-destinations.json", lambda o: f"alerts/destinations/{o['name']}"),
        ("alerts.json", lambda o: f"{o['stream_name']}/alerts/{o['name']}"),
    ]:
        log(f"{name}:")
        ok, fail = apply(auth, name, path_for)
        total_ok += ok
        total_fail += fail
    log(f"reconcile complete: {total_ok} applied, {total_fail} failed")
    sys.exit(1 if total_fail else 0)


if __name__ == "__main__":
    main()
