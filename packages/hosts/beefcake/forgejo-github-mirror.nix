{
  config,
  pkgs,
  lib,
  ...
}:
let
  repos = [
    "nix"
    # Add more repo names here as needed
  ];

  mirrorScript = pkgs.writeShellScript "forgejo-github-mirror" ''
    set -euo pipefail

    APP_ID="$(cat '${config.sops.secrets.github-app-id.path}')"
    APP_KEY='${config.sops.secrets.github-app-key.path}'
    INSTALLATION_ID="$(cat '${config.sops.secrets.github-app-installation-id.path}')"
    GITHUB_API="https://api.github.com"
    GITHUB_USER="lytedev"
    REPO_BASE="/storage/forgejo/repositories/lytedev"

    # --- Generate GitHub App installation token (JWT -> token exchange) ---
    now=$(${pkgs.coreutils}/bin/date +%s)
    iat=$((now - 60))
    exp=$((now + 600))

    b64url() {
      ${pkgs.openssl}/bin/openssl enc -base64 -A | tr '+/' '-_' | tr -d '='
    }

    header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
    payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$iat" "$exp" "$APP_ID" | b64url)
    signature=$(printf '%s.%s' "$header" "$payload" | \
      ${pkgs.openssl}/bin/openssl dgst -sha256 -sign "$APP_KEY" -binary | b64url)
    jwt="$header.$payload.$signature"

    GITHUB_TOKEN=$(${pkgs.curl}/bin/curl -sf \
      -X POST "$GITHUB_API/app/installations/$INSTALLATION_ID/access_tokens" \
      -H "Authorization: Bearer $jwt" \
      -H "Accept: application/vnd.github+json" | ${pkgs.jq}/bin/jq -r '.token')

    if [ -z "$GITHUB_TOKEN" ] || [ "$GITHUB_TOKEN" = "null" ]; then
      echo "ERROR: Failed to get GitHub installation token"
      exit 1
    fi

    echo "Got GitHub installation token"

    # --- Mirror each repo ---
    failed=0
    synced=0
    for name in ${lib.concatStringsSep " " repos}; do
      echo "Syncing $name..."
      if ${pkgs.gitMinimal}/bin/git -C "$REPO_BASE/$name.git" \
        push --mirror "https://x-access-token:''${GITHUB_TOKEN}@github.com/$GITHUB_USER/$name.git" 2>&1; then
        echo "  Done: $name"
        synced=$((synced + 1))
      else
        echo "  FAILED: $name"
        failed=$((failed + 1))
      fi
    done

    echo "Mirror sync complete. Synced: $synced, Failed: $failed"
    [ "$failed" -gt 0 ] && exit 1
    exit 0
  '';
in
{
  sops.secrets.github-app-id.mode = "0400";
  sops.secrets.github-app-key = {
    mode = "0400";
    owner = "forgejo";
  };
  sops.secrets.github-app-installation-id.mode = "0400";
  sops.secrets.github-mirror-failure-webhook.mode = "0400";

  systemd.services.forgejo-github-mirror = {
    description = "Mirror Forgejo repositories to GitHub";
    after = [
      "forgejo.service"
      "sops-nix.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "forgejo";
      Group = "forgejo";
      OnFailure = [ "forgejo-github-mirror-notify@%n.service" ];
    };
    script = toString mirrorScript;
  };

  systemd.timers.forgejo-github-mirror = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "15m";
      Unit = "forgejo-github-mirror.service";
    };
  };

  systemd.services."forgejo-github-mirror-notify@" = {
    description = "Notify on GitHub mirror failure";
    serviceConfig.Type = "oneshot";
    script = ''
      webhook_url="$(cat '${config.sops.secrets.github-mirror-failure-webhook.path}')"
      ${pkgs.curl}/bin/curl -sf -X POST "$webhook_url" \
        -H 'Content-Type: application/json' \
        -d '{"text": "GitHub mirror sync failed. Check: journalctl -u forgejo-github-mirror"}'
    '';
  };
}
