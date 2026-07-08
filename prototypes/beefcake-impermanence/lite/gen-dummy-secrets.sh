#!/usr/bin/env bash
# Generate lite/dummy-secrets.yml: every sops secret name the beefcake config
# references, with FORMAT-PLAUSIBLE throwaway values, encrypted to the
# prototype test age key. This is the "mirror production without copying
# secrets" harness the validation tier needs (issues/open/blue-green.md).
#
# Run from prototypes/beefcake-impermanence/:  bash lite/gen-dummy-secrets.sh
# Requires: nix (sops, openssl, nix key tooling fetched ad hoc).
set -euo pipefail
cd "$(dirname "$0")"

RECIPIENT=$(nix shell nixpkgs#age -c age-keygen -y ../keys/age-test-key.txt)

# Derive the secret key list from the EVALUATED lite config (the exact config
# the deploy gate builds) — never hardcode it. A hardcoded list drifted twice
# (infra-alert-webhook-url) and false-failed the gate. extendModules matches
# what lite/run-lite.sh builds; needs an existing dummy-secrets.yml to eval
# against (we only read KEY NAMES here, so a stale one bootstraps fine).
repo=$(cd ../../.. && pwd)
KEYS_JSON=$(nix eval --impure --json --expr "
  let f = builtins.getFlake \"path:$repo\";
      lite = f.nixosConfigurations.beefcake.extendModules {
        modules = [ $repo/prototypes/beefcake-impermanence/lite/beefcake-lite.nix ];
      };
  in map (s: s.key) (builtins.attrValues lite.config.sops.secrets)")
export KEYS_JSON
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

b64() { head -c "${1:-32}" /dev/urandom | base64 -w0; }

# Format-critical values first.
nix key generate-secret --key-name nix.h.lyte.dev-test > "$work/cachekey" 2>/dev/null \
  || nix shell nixpkgs#nix -c nix key generate-secret --key-name nix.h.lyte.dev-test > "$work/cachekey"
RSA_PEM=$(nix shell nixpkgs#openssl -c openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null)
SSH_KEY_FILE="$work/sshkey"
ssh-keygen -q -t ed25519 -N '' -C dummy -f "$SSH_KEY_FILE"

py_yaml() {
python3 - "$@" <<'PYEOF'
import json, subprocess, sys, os, base64

def rand(n=32):
    return base64.b64encode(os.urandom(n)).decode()

with open(sys.argv[1]) as f:
    cachekey = f.read().strip()
with open(sys.argv[2]) as f:
    rsa_pem = f.read()
with open(sys.argv[3]) as f:
    ssh_pem = f.read()

env = lambda *names: "\n".join(f"{n}=dummy-{rand(6)}" for n in names)

secrets = {
    # --- format-critical ---
    "nix-cache-priv-key": cachekey,
    "stalwart-dkim-private-key": rsa_pem,
    "github-app-key": rsa_pem,
    "restic-rascal-ssh-private-key": ssh_pem,
    "restic-ssh-priv-key-benland": ssh_pem,
    "factorio-server-settings": "{}",
    "garage.toml": "# dummy\n",
    "mmrelay-credentials": "{}",
    # kanidm remaps via key=: the FILE keys are persons/service-accounts
    "persons": "{}",
    "service-accounts": "{}",
    # nested dict: config references home-assistant/<sub-key>
    "home-assistant": {
        "hearth-auth-header": "Bearer dummy",
        "abs-auth-header": "Bearer dummy",
        "tv-control-auth": "dummy",
    },
    # --- env files: seed plausible var names; missing ones surface as
    #     app-level failures, which land in the acceptable-fail bucket ---
    "openobserve.env": env("ZO_ROOT_USER_EMAIL", "ZO_ROOT_USER_PASSWORD"),
    "openobserve-otel.env": env("OTEL_AUTH_HEADER"),
    "openobserve-prometheus.env": env("PROM_AUTH"),
    "bulwark.env": env("BULWARK_SECRET"),
    "forgejo-runner.env": env("TOKEN"),
    "happy.env": env("HAPPY_SECRET"),
    "jland.env": env("JLAND_SECRET"),
    "dawncraft.env": env("DAWNCRAFT_SECRET"),
}

# Everything else comes from the EVALUATED config (KEYS_JSON), so new
# secrets can never again drift the fixture: slash-keys -> nested dicts;
# url/webhook names -> URL-shaped values; .env -> a generic var; the rest ->
# opaque random strings. Format-critical entries defined above win.
needed = json.loads(os.environ["KEYS_JSON"])
for key in needed:
    parts = key.split("/")
    if len(parts) == 1 and parts[0] in secrets:
        continue  # format-critical special case already set
    if len(parts) > 1:
        node = secrets.setdefault(parts[0], {})
        if not isinstance(node, dict):
            continue
        for p in parts[1:-1]:
            node = node.setdefault(p, {})
        node.setdefault(parts[-1], "dummy-" + rand(6))
    elif "webhook" in key or key.endswith("-url"):
        secrets[key] = "http://127.0.0.1:9/dummy-webhook"
    elif key.endswith(".env"):
        secrets[key] = "DUMMY_SECRET=dummy-" + rand(6)
    else:
        secrets[key] = rand()

print(json.dumps(secrets))
PYEOF
}

py_yaml "$work/cachekey" <(printf '%s' "$RSA_PEM") "$SSH_KEY_FILE" > "$work/secrets.json"

# JSON -> YAML -> sops encrypt
python3 - "$work/secrets.json" > "$work/plain.yml" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
for k in sorted(data):
    v = data[k]
    if isinstance(v, dict):
        print(f"{k}:")
        for sk, sv in v.items():
            print(f"    {sk}: {json.dumps(sv)}")
        continue
    if "\n" in v:
        print(f"{k}: |")
        for line in v.rstrip("\n").split("\n"):
            print(f"    {line}")
    else:
        print(f"{k}: {json.dumps(v)}")
PYEOF

printf 'creation_rules:\n  - age: %s\n' "$RECIPIENT" > "$work/.sops.yaml"
nix shell nixpkgs#sops -c sops --config "$work/.sops.yaml" --encrypt "$work/plain.yml" > dummy-secrets.yml
echo "wrote lite/dummy-secrets.yml ($(grep -c '^[a-z]' dummy-secrets.yml) top-level keys incl. sops metadata)"
