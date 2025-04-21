{ lib, config, ... }:

{
  services.headscale = {
    enable = false; # TODO: setup headscale?
    address = "127.0.0.1";
    port = 7777;
    settings = {
      server_url = "https://tailscale.vpn.h.lyte.dev";
      db_type = "sqlite3";
      db_path = "/var/lib/headscale/db.sqlite";

      derp.server = {
        enable = true;
        region_id = 999;
        stun_listen_addr = "0.0.0.0:3478";
      };

      dns_config = {
        magic_dns = true;
        base_domain = "vpn.h.lyte.dev";
        domains = [
          "ts.vpn.h.lyte.dev"
        ];
        nameservers = [
          "1.1.1.1"
          # "192.168.0.1"
        ];
        override_local_dns = true;
      };
    };
  };
  services.caddy.virtualHosts."tailscale.vpn.h.lyte.dev" = lib.mkIf config.services.headscale.enable {
    extraConfig = ''
      reverse_proxy http://localhost:${toString config.services.headscale.port}
    '';
  };
  networking.firewall.allowedUDPPorts = lib.mkIf config.services.headscale.enable [ 3478 ];
}
