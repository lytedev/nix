#!/usr/bin/env python3
"""Notify a Matrix room (via a hookshot generic webhook) about new Inbox mail.

Auth model: Kanidm rolling refresh token for the bulwark-webmail public
client. STATE_DIR/refresh_token is seeded once interactively (get-token.sh
--save-refresh) and rolled forward on every refresh; losing it requires
re-seeding. Access tokens live in memory only.

Flow: JMAP EventSource (RFC 8620 §7.3) -> on Email StateChange, query
Inbox messages newer than the last seen receivedAt -> POST a line per
message to the hookshot webhook.
"""

import json
import os
import sys
import time
import urllib.request
import urllib.parse

ISSUER = os.environ["KANIDM_ISSUER"]
CLIENT_ID = os.environ["OAUTH_CLIENT_ID"]
JMAP_BASE = os.environ["JMAP_BASE"]  # e.g. https://mail.lyte.dev
WEBHOOK_URL_FILE = os.environ["WEBHOOK_URL_FILE"]
STATE_DIR = os.environ["STATE_DIRECTORY"]

REFRESH_FILE = os.path.join(STATE_DIR, "refresh_token")
LASTSEEN_FILE = os.path.join(STATE_DIR, "last_seen")

access_token = None
account_id = None
inbox_id = None


def log(msg):
    print(msg, flush=True)


def http(url, data=None, headers=None, timeout=30):
    req = urllib.request.Request(url, data=data, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def refresh_access_token():
    """Exchange the stored refresh token; persist the rolled replacement."""
    global access_token
    with open(REFRESH_FILE) as f:
        refresh = f.read().strip()
    disco = json.loads(http(f"{ISSUER}/.well-known/openid-configuration"))
    body = urllib.parse.urlencode(
        {
            "grant_type": "refresh_token",
            "client_id": CLIENT_ID,
            "refresh_token": refresh,
        }
    ).encode()
    tok = json.loads(
        http(
            disco["token_endpoint"],
            data=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
    )
    access_token = tok["access_token"]
    new_refresh = tok.get("refresh_token")
    if new_refresh:
        tmp = REFRESH_FILE + ".tmp"
        with open(tmp, "w") as f:
            f.write(new_refresh)
        os.replace(tmp, REFRESH_FILE)
    log("token: refreshed")


def jmap(method_calls):
    body = json.dumps(
        {
            "using": [
                "urn:ietf:params:jmap:core",
                "urn:ietf:params:jmap:mail",
            ],
            "methodCalls": method_calls,
        }
    ).encode()
    return json.loads(
        http(
            f"{JMAP_BASE}/jmap",
            data=body,
            headers={
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
            },
        )
    )


def init_session():
    global account_id, inbox_id
    sess = json.loads(
        http(
            f"{JMAP_BASE}/jmap/session",
            headers={"Authorization": f"Bearer {access_token}"},
        )
    )
    account_id = sess["primaryAccounts"]["urn:ietf:params:jmap:mail"]
    boxes = jmap([["Mailbox/get", {"accountId": account_id, "properties": ["role"]}, "0"]])
    for mb in boxes["methodResponses"][0][1]["list"]:
        if mb.get("role") == "inbox":
            inbox_id = mb["id"]
    log(f"session: account={account_id} inbox={inbox_id}")
    return sess


def last_seen():
    try:
        with open(LASTSEEN_FILE) as f:
            return f.read().strip()
    except FileNotFoundError:
        return None


def set_last_seen(ts):
    tmp = LASTSEEN_FILE + ".tmp"
    with open(tmp, "w") as f:
        f.write(ts)
    os.replace(tmp, LASTSEEN_FILE)


def notify_new_mail():
    since = last_seen()
    filt = {"inMailbox": inbox_id}
    if since:
        filt = {"operator": "AND", "conditions": [filt, {"after": since}]}
    res = jmap(
        [
            [
                "Email/query",
                {
                    "accountId": account_id,
                    "filter": filt,
                    "sort": [{"property": "receivedAt", "isAscending": True}],
                    "limit": 20,
                },
                "0",
            ],
            [
                "Email/get",
                {
                    "accountId": account_id,
                    "#ids": {"resultOf": "0", "name": "Email/query", "path": "/ids"},
                    "properties": ["from", "subject", "receivedAt"],
                },
                "1",
            ],
        ]
    )
    emails = res["methodResponses"][1][1]["list"]
    if not emails:
        return
    with open(WEBHOOK_URL_FILE) as f:
        webhook = f.read().strip()
    for e in emails:
        frm = (e.get("from") or [{}])[0]
        sender = frm.get("name") or frm.get("email") or "unknown"
        subject = e.get("subject") or "(no subject)"
        text = f"\U0001F4EC {sender} — {subject}"
        http(
            webhook,
            data=json.dumps({"text": text}).encode(),
            headers={"Content-Type": "application/json"},
        )
        log(f"notified: {text}")
        set_last_seen(e["receivedAt"])


def event_loop(sess):
    url = sess["eventSourceUrl"].replace("{types}", "Email").replace("{closeafter}", "no").replace("{ping}", "60")
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {access_token}", "Accept": "text/event-stream"})
    with urllib.request.urlopen(req, timeout=120) as stream:
        log("eventsource: connected")
        for raw in stream:
            line = raw.decode(errors="replace").strip()
            if line.startswith("event: state"):
                continue
            if line.startswith("data:"):
                notify_new_mail()


def main():
    # initial catch-up marker: never spam history on first boot
    if last_seen() is None:
        set_last_seen(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
    backoff = 5
    while True:
        try:
            refresh_access_token()
            sess = init_session()
            notify_new_mail()  # catch up anything missed while down
            backoff = 5
            event_loop(sess)
        except KeyboardInterrupt:
            sys.exit(0)
        except Exception as exc:  # noqa: BLE001 — reconnect on anything
            log(f"error: {exc!r} — reconnecting in {backoff}s")
            time.sleep(backoff)
            backoff = min(backoff * 2, 300)


if __name__ == "__main__":
    main()
