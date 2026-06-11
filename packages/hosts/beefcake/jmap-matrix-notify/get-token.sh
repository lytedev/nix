#!/usr/bin/env nix-shell
#!nix-shell -i bash -p openssl jq curl python3
# Obtain a Kanidm bearer token for the bulwark-webmail client via
# authorization-code + PKCE with a loopback redirect. Prints the access
# token to stdout (everything else to stderr).
set -euo pipefail

ISSUER="https://idm.h.lyte.dev/oauth2/openid/bulwark-webmail"
CLIENT_ID="bulwark-webmail"
PORT=18923
REDIRECT_URI="http://localhost:${PORT}/"

disco=$(curl -sf "$ISSUER/.well-known/openid-configuration")
AUTH_EP=$(jq -r .authorization_endpoint <<<"$disco")
TOKEN_EP=$(jq -r .token_endpoint <<<"$disco")

# PKCE
verifier=$(head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n')
challenge=$(printf %s "$verifier" | openssl dgst -sha256 -binary | base64 | tr '+/' '-_' | tr -d '=\n')
state=$(head -c 16 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n')

url="${AUTH_EP}?response_type=code&client_id=${CLIENT_ID}&redirect_uri=$(jq -rn --arg u "$REDIRECT_URI" '$u|@uri')&scope=openid+email+profile&state=${state}&code_challenge=${challenge}&code_challenge_method=S256"

echo "Opening browser for Kanidm sign-in..." >&2
xdg-open "$url" >/dev/null 2>&1 || true
{
  echo ""
  echo "If no browser tab appeared, open this URL manually:"
  echo "$url"
  echo ""
} >&2

request_path=$(python3 - "$PORT" <<'PY'
import sys, http.server
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        print(self.path, flush=True)
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(b'<html><body><h2>Token captured \xe2\x80\x94 you can close this tab.</h2></body></html>')
    def log_message(self, *a):
        pass
http.server.HTTPServer(('127.0.0.1', int(sys.argv[1])), H).handle_request()
PY
)

code=$(grep -oP 'code=\K[^&]+' <<<"$request_path" || true)
got_state=$(grep -oP 'state=\K[^&]+' <<<"$request_path" || true)

[ -n "$code" ] || { echo "no code captured (got: $request_path)" >&2; exit 1; }
[ "$got_state" = "$state" ] || { echo "state mismatch" >&2; exit 1; }

resp=$(curl -sf -X POST "$TOKEN_EP" \
  -d "grant_type=authorization_code" \
  -d "client_id=${CLIENT_ID}" \
  -d "code=${code}" \
  -d "redirect_uri=${REDIRECT_URI}" \
  -d "code_verifier=${verifier}")

if [ "${1:-}" = "--save-refresh" ]; then
  # refresh token to stdout (for seeding jmap-matrix-notify's state)
  jq -r .refresh_token <<<"$resp"
else
  jq -r .access_token <<<"$resp"
fi
