{
  lib,
  config,
  pkgs,
  ...
}:

let
  # Declarative node->tag assignment.
  #
  # Headscale has no native declarative node->tag map: its ACL policy declares
  # tag *ownership* (tagOwners), not *assignment*. Assignment is otherwise
  # imperative DB state set with `headscale nodes tag`. Client-side advertising
  # (`tailscale up --advertise-tags`) is not a usable substitute here: the
  # NixOS tailscale module only runs `tailscale up` when an authKeyFile is set
  # (so it never fires on interactively-OIDC-authed laptops), `tailscale set`
  # has no --advertise-tags flag, and it can't cover non-NixOS devices or
  # server-preauthkey nodes that don't own the tag.
  #
  # So we keep forced tags as the assignment mechanism but make them
  # declarative: this map is the source of truth, reconciled onto Headscale by
  # the oneshot below (and a daily timer, to re-apply after a node
  # re-registers under a new id). Matching is by stable given_name. Covers
  # every device uniformly — OIDC laptops, the server-authed dragon, and the
  # non-NixOS zenfoneten phone.
  nodeTags = {
    dragon = [ "tag:admindevice" ];
    foxtrot = [ "tag:admindevice" ];
    thinker = [ "tag:admindevice" ];
    flab = [ "tag:admindevice" ];
    babyflip = [ "tag:admindevice" ];
    zenfoneten = [ "tag:admindevice" ];
  };

  # name<TAB>comma,separated,tags — one line per node, consumed by the script.
  desiredTagsFile = pkgs.writeText "headscale-desired-node-tags" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: tags: "${name}\t${lib.concatStringsSep "," tags}") nodeTags
    )
  );

  reconcileNodeTags = pkgs.writeShellApplication {
    name = "headscale-reconcile-node-tags";
    runtimeInputs = [
      config.services.headscale.package
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail

      # Headscale must be serving its socket before the CLI works; retry briefly.
      nodes_json=""
      for _ in $(seq 1 30); do
        if nodes_json=$(headscale nodes list -o json 2>/dev/null); then break; fi
        sleep 2
      done
      if [ -z "$nodes_json" ]; then
        echo "headscale not responding; skipping node-tag reconcile" >&2
        exit 0
      fi

      while IFS=$'\t' read -r name want_csv; do
        [ -n "$name" ] || continue

        row=$(printf '%s' "$nodes_json" | jq -c --arg n "$name" \
          'map(select(.given_name == $n)) | first // empty')
        if [ -z "$row" ]; then
          echo "node '$name' not registered; skipping" >&2
          continue
        fi

        id=$(printf '%s' "$row" | jq -r '.id')
        current=$(printf '%s' "$row" | jq -r '(.tags // []) | sort | join(",")')
        want=$(printf '%s' "$want_csv" | tr ',' '\n' | sort | paste -sd, -)

        if [ "$current" = "$want" ]; then
          continue
        fi

        tag_args=()
        IFS=',' read -ra want_tags <<< "$want_csv"
        for t in "''${want_tags[@]}"; do
          [ -n "$t" ] && tag_args+=(-t "$t")
        done

        headscale nodes tag -i "$id" "''${tag_args[@]}"
        echo "reconciled '$name' (id $id): [$current] -> [$want]"
      done < ${desiredTagsFile}
    '';
  };
in
{
  sops.secrets.headscale-oidc-secret = {
    mode = "0400";
    owner = "headscale";
    group = "headscale";
  };

  services.headscale = {
    enable = true;
    address = "127.0.0.1";
    port = 7777;
    settings = {
      server_url = "https://vpn.h.lyte.dev";

      database = {
        type = "sqlite3";
        sqlite.path = "/var/lib/headscale/db.sqlite";
      };

      # OIDC authentication via Kanidm
      oidc = {
        only_start_if_oidc_is_available = true;
        issuer = "https://idm.h.lyte.dev/oauth2/openid/vpn.h.lyte.dev";
        client_id = "vpn.h.lyte.dev";
        client_secret_path = config.sops.secrets.headscale-oidc-secret.path;
        scope = [
          "openid"
          "profile"
          "email"
        ];
        # Map email domain to allow
        allowed_domains = [ "lyte.dev" ];
        # Or use allowed_groups once Kanidm groups are configured
        # allowed_groups = [ "family" "administrators" "trusted-friends" ];
        # Key expiry for OIDC-authenticated devices. "0" = never auto-expire:
        # devices persist in the tailnet until *manually* removed
        # (`headscale nodes expire|delete <id>`), instead of silently dropping
        # out every 90d. Occasionally-used devices (e.g. the Steam Deck) kept
        # falling out and re-registering under temp names. Manual kick-out and
        # ACLs (tag:admindevice -> *:* already allows admin SSH everywhere) are
        # unaffected. Applies to nodes on their next (re)authentication.
        expiry = "0";
      };

      derp.server = {
        enable = true;
        region_id = 999;
        region_name = "h.lyte.dev";
        stun_listen_addr = "0.0.0.0:3478";
      };

      dns = {
        magic_dns = true;
        base_domain = "internal.vpn.h.lyte.dev";
        search_domains = [ ];
        nameservers.global = [
          "192.168.0.1"
          "1.1.1.1"
        ];
        override_local_dns = true;
      };

      # ACL policy. Declares tag *ownership* (tagOwners); node->tag *assignment*
      # is reconciled from the `nodeTags` map at the top of this file.
      policy.path = ./headscale-acl.json;

      # Logging
      log.level = "info";
    };
  };

  # Reconcile the declarative `nodeTags` map onto Headscale's forced tags.
  # Runs after headscale starts and daily thereafter (to re-apply tags lost
  # when a node re-registers under a new id).
  systemd.services.headscale-reconcile-node-tags = lib.mkIf config.services.headscale.enable {
    description = "Reconcile Headscale node tags to declarative desired state";
    after = [ "headscale.service" ];
    wants = [ "headscale.service" ];
    wantedBy = [ "multi-user.target" ];
    startAt = "daily";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe reconcileNodeTags;
    };
  };

  services.caddy.virtualHosts."vpn.h.lyte.dev" = lib.mkIf config.services.headscale.enable {
    extraConfig = ''
      reverse_proxy http://localhost:${toString config.services.headscale.port}
    '';
  };

  networking.firewall.allowedUDPPorts = lib.mkIf config.services.headscale.enable [ 3478 ];
}
