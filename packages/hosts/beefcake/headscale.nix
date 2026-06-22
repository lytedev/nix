{ lib, config, ... }:

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

      # ACL policy
      policy.path = ./headscale-acl.json;

      # Logging
      log.level = "info";
    };
  };

  services.caddy.virtualHosts."vpn.h.lyte.dev" = lib.mkIf config.services.headscale.enable {
    extraConfig = ''
      reverse_proxy http://localhost:${toString config.services.headscale.port}
    '';
  };

  networking.firewall.allowedUDPPorts = lib.mkIf config.services.headscale.enable [ 3478 ];
}
