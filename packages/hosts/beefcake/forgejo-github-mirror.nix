{
  config,
  pkgs,
  lib,
  ...
}:
let
  repos = [
    "nix"
    # Add more repo names here as needed. The GitHub repo's visibility is forced
    # to match the forge repo's (private forge -> private GitHub) on every sync,
    # so it is always safe to add a private repo. You DO have to create the empty
    # GitHub repo once first — GitHub Apps can't create repos in a user account.
  ];

  # Local Forgejo API, used to read each repo's visibility (see the sync loop).
  forgejoSrv = config.services.forgejo.settings.server;
  forgejoLocal = "http://${forgejoSrv.HTTP_ADDR}:${toString forgejoSrv.HTTP_PORT}";

  # Persists the last successfully-mirrored "signature" per repo so idle runs make
  # ZERO GitHub contact (see the change-detection guard in the script).
  stateDir = "/var/lib/forgejo-github-mirror";

  git = "${pkgs.gitMinimal}/bin/git";
  curl = "${pkgs.curl}/bin/curl";
  jq = "${pkgs.jq}/bin/jq";
  openssl = "${pkgs.openssl}/bin/openssl";
  sha256 = "${pkgs.coreutils}/bin/sha256sum";

  mirrorScript = pkgs.writeShellScript "forgejo-github-mirror" ''
    set -euo pipefail

    GITHUB_API="https://api.github.com"
    GITHUB_USER="lytedev"
    REPO_BASE="/storage/forgejo/repositories/lytedev"
    repos="${lib.concatStringsSep " " repos}"

    # Compute a repo's mirror "signature" + metadata using only LOCAL data (the
    # bare git repo and the local Forgejo API). Echoes: "<sig> <default-branch> <want_private>".
    # The signature covers the default branch tip + every tag object AND the forge
    # visibility, so a new commit, a new/changed tag, OR a public<->private flip all
    # invalidate it — without ever touching GitHub.
    repo_state() {
      name="$1"
      repo="$REPO_BASE/$name.git"
      db=$(${git} -C "$repo" symbolic-ref --short HEAD)
      refsig=$(${git} -C "$repo" for-each-ref \
        --format='%(objectname) %(refname)' "refs/heads/$db" 'refs/tags/*' \
        | ${sha256} | cut -d' ' -f1)
      # Unauthenticated local Forgejo API: 200 => public, anything else => private.
      fcode=$(${curl} -s -o /dev/null -w '%{http_code}' \
        "${forgejoLocal}/api/v1/repos/$GITHUB_USER/$name" || echo 000)
      if [ "$fcode" = "200" ]; then wp=false; else wp=true; fi
      sig=$(printf '%s|priv=%s' "$refsig" "$wp" | ${sha256} | cut -d' ' -f1)
      printf '%s %s %s\n' "$sig" "$db" "$wp"
    }

    # --- Phase 1: which repos changed? (LOCAL only — no GitHub contact) ---
    changed=""
    nchanged=0
    for name in $repos; do
      info=$(repo_state "$name")
      sig=$(echo "$info" | cut -d' ' -f1)
      sf="${stateDir}/$name.synced"
      if [ -f "$sf" ] && [ "$(cat "$sf")" = "$sig" ]; then
        echo "$name: unchanged since last sync — skipping"
      else
        changed="$changed $name"
        nchanged=$((nchanged + 1))
      fi
    done

    if [ "$nchanged" -eq 0 ]; then
      echo "All repos up-to-date; no GitHub contact needed."
      exit 0
    fi
    echo "Changed repos:$changed"

    # --- Phase 2: mint a GitHub App installation token (only because something changed) ---
    APP_ID="$(cat '${config.sops.secrets.github-app-id.path}')"
    APP_KEY='${config.sops.secrets.github-app-key.path}'
    INSTALLATION_ID="$(cat '${config.sops.secrets.github-app-installation-id.path}')"

    now=$(${pkgs.coreutils}/bin/date +%s)
    iat=$((now - 60))
    exp=$((now + 600))

    b64url() { ${openssl} enc -base64 -A | tr '+/' '-_' | tr -d '='; }

    header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
    payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$iat" "$exp" "$APP_ID" | b64url)
    signature=$(printf '%s.%s' "$header" "$payload" | \
      ${openssl} dgst -sha256 -sign "$APP_KEY" -binary | b64url)
    jwt="$header.$payload.$signature"

    GITHUB_TOKEN=$(${curl} -sf \
      -X POST "$GITHUB_API/app/installations/$INSTALLATION_ID/access_tokens" \
      -H "Authorization: Bearer $jwt" \
      -H "Accept: application/vnd.github+json" | ${jq} -r '.token')

    if [ -z "$GITHUB_TOKEN" ] || [ "$GITHUB_TOKEN" = "null" ]; then
      echo "ERROR: Failed to get GitHub installation token"
      exit 1
    fi
    echo "Got GitHub installation token"

    # --- Phase 3: mirror each changed repo (default branch + tags only) ---
    failed=0
    synced=0
    for name in $changed; do
      repo="$REPO_BASE/$name.git"
      info=$(repo_state "$name")
      sig=$(echo "$info" | cut -d' ' -f1)
      db=$(echo "$info" | cut -d' ' -f2)
      want_private=$(echo "$info" | cut -d' ' -f3)
      echo "Syncing $name (branch=$db, private=$want_private)..."

      # The GitHub repo must already exist (Apps can't create repos in a user acct).
      resp=$(${curl} -s -w $'\n%{http_code}' \
        -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
        "$GITHUB_API/repos/$GITHUB_USER/$name")
      gcode=$(printf '%s' "$resp" | tail -n1)
      if [ "$gcode" != "200" ]; then
        echo "  SKIP: github.com/$GITHUB_USER/$name doesn't exist — create the empty repo first"
        failed=$((failed + 1)); continue
      fi
      cur_private=$(printf '%s' "$resp" | sed '$d' | ${jq} -r '.private')

      # Force GitHub visibility to match the forge BEFORE pushing any content.
      if [ "$cur_private" != "$want_private" ]; then
        echo "  visibility: forge private=$want_private, GitHub was $cur_private — updating"
        if ! ${curl} -sf -X PATCH \
          -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
          "$GITHUB_API/repos/$GITHUB_USER/$name" -d "{\"private\": $want_private}" >/dev/null; then
          echo "  FAILED to set visibility for $name — skipping push to avoid a leak"
          failed=$((failed + 1)); continue
        fi
      fi

      # Syndicate the default branch + all tags (force, to follow upstream rewrites).
      # NOT --mirror: feature/WIP branches stay private to the forge, and we never
      # prune refs that only exist on GitHub.
      if ${git} -C "$repo" push --force \
        "https://x-access-token:''${GITHUB_TOKEN}@github.com/$GITHUB_USER/$name.git" \
        "refs/heads/$db:refs/heads/$db" "refs/tags/*:refs/tags/*" 2>&1; then
        echo "  Done: $name (private=$want_private)"
        echo "$sig" > "${stateDir}/$name.synced"
        synced=$((synced + 1))
      else
        echo "  FAILED: $name"
        failed=$((failed + 1))
      fi
    done

    echo "Mirror sync complete. Synced: $synced, Failed: $failed"
    if [ "$failed" -gt 0 ]; then exit 1; fi
    exit 0
  '';
in
{
  sops.secrets.github-app-id = {
    mode = "0400";
    owner = "forgejo";
  };
  sops.secrets.github-app-key = {
    mode = "0400";
    owner = "forgejo";
  };
  sops.secrets.github-app-installation-id = {
    mode = "0400";
    owner = "forgejo";
  };
  sops.secrets.github-mirror-failure-webhook.mode = "0400";

  systemd.services.forgejo-github-mirror = {
    description = "Mirror Forgejo repositories to GitHub";
    after = [
      "forgejo.service"
      "sops-nix.service"
    ];
    # OnFailure belongs in [Unit], not [Service]; fire the Matrix notifier on failure.
    unitConfig.OnFailure = [ "forgejo-github-mirror-notify@%n.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "forgejo";
      Group = "forgejo";
      StateDirectory = "forgejo-github-mirror";
      StateDirectoryMode = "0700";
    };
    script = toString mirrorScript;
  };

  systemd.timers.forgejo-github-mirror = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      # Hourly is plenty: the change-detection guard makes idle runs free (no
      # GitHub contact), so this only bounds how quickly a real change syndicates.
      OnUnitActiveSec = "1h";
      Unit = "forgejo-github-mirror.service";
    };
  };

  systemd.services."forgejo-github-mirror-notify@" = {
    description = "Notify on GitHub mirror failure";
    serviceConfig.Type = "oneshot";
    script = ''
      webhook_url="$(cat '${config.sops.secrets.github-mirror-failure-webhook.path}')"
      ${curl} -sf -X POST "$webhook_url" \
        -H 'Content-Type: application/json' \
        -d '{"text": "GitHub mirror sync failed. Check: journalctl -u forgejo-github-mirror"}'
    '';
  };
}
