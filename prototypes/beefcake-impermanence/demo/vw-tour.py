#!/usr/bin/env python3
"""Drive vaultwarden as a real client: register, login, add cipher, list.

Usage: vw_tour.py <base_url> register|login|add <name>|list
Credentials fixed for the demo tour. The 'encrypted' blobs are well-formed
but opaque placeholders — the server never decrypts them.
"""
import base64
import hashlib
import json
import os
import sys
import urllib.request
import urllib.parse
import uuid

BASE = sys.argv[1].rstrip("/")
ACTION = sys.argv[2]
EMAIL = "daniel-demo@example.com"
PASSWORD = b"demo-master-password"
ITER = 600_000


def b64(b: bytes) -> str:
    return base64.b64encode(b).decode()


def master_key() -> bytes:
    return hashlib.pbkdf2_hmac("sha256", PASSWORD, EMAIL.encode(), ITER, 32)


def master_hash() -> str:
    return b64(hashlib.pbkdf2_hmac("sha256", master_key(), PASSWORD, 1, 32))


def fake_enc_blob(nbytes: int = 32) -> str:
    iv, data, mac = os.urandom(16), os.urandom(nbytes), os.urandom(32)
    return f"2.{b64(iv)}|{b64(data)}|{b64(mac)}"


def req(path: str, data=None, token=None, form=False):
    url = BASE + path
    headers = {"User-Agent": "vw-tour/1.0"}
    if token:
        headers["Authorization"] = "Bearer " + token
    if data is not None:
        if form:
            body = urllib.parse.urlencode(data).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        else:
            body = json.dumps(data).encode()
            headers["Content-Type"] = "application/json"
    else:
        body = None
    r = urllib.request.Request(url, data=body, headers=headers)
    try:
        with urllib.request.urlopen(r, timeout=15) as resp:
            raw = resp.read().decode() or "{}"
            return json.loads(raw)
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code} on {path}: {e.read().decode()[:400]}", file=sys.stderr)
        raise


def login() -> str:
    data = {
        "grant_type": "password",
        "username": EMAIL,
        "password": master_hash(),
        "scope": "api offline_access",
        "client_id": "web",
        "deviceType": "9",
        "deviceIdentifier": str(uuid.uuid5(uuid.NAMESPACE_DNS, "vw-tour")),
        "deviceName": "vw-tour",
    }
    out = req("/identity/connect/token", data, form=True)
    return out["access_token"]


if ACTION == "register":
    # New two-step flow: with SMTP disabled the verification token is
    # returned directly in the response body.
    tok = req(
        "/identity/accounts/register/send-verification-email",
        {"email": EMAIL, "name": "Demo Daniel", "receiveMarketingEmails": False},
    )
    req(
        "/identity/accounts/register/finish",
        {
            "email": EMAIL,
            "emailVerificationToken": tok,
            "masterPasswordHash": master_hash(),
            "masterPasswordHint": None,
            "userSymmetricKey": fake_enc_blob(64),
            "kdf": 0,
            "kdfIterations": ITER,
            "userAsymmetricKeys": {
                "publicKey": b64(os.urandom(128)),
                "encryptedPrivateKey": fake_enc_blob(256),
            },
        },
    )
    print("REGISTERED", EMAIL)
elif ACTION == "login":
    tok = login()
    print("LOGIN-OK token-len", len(tok))
elif ACTION == "add":
    name = sys.argv[3]
    tok = login()
    out = req(
        "/api/ciphers",
        {
            "type": 1,
            "name": fake_enc_blob(),
            "notes": None,
            "favorite": False,
            "login": {
                "username": fake_enc_blob(),
                "password": fake_enc_blob(),
                "uris": None,
            },
            # cleartext marker so `list` can prove continuity without crypto:
            "fields": [{"type": 0, "name": fake_enc_blob(), "value": fake_enc_blob()}],
        },
        token=tok,
    )
    print("CIPHER-ADDED id", out.get("id", "?"), "marker", name)
elif ACTION == "list":
    tok = login()
    out = req("/api/ciphers", token=tok)
    items = out.get("data", out if isinstance(out, list) else [])
    print("CIPHER-COUNT", len(items))
    for it in items:
        print("  cipher", it.get("id"))
else:
    sys.exit("unknown action")
