{ config, ... }:
{
  # transmission
  systemd.tmpfiles.settings = {
    "10-transmission" = {
      "/storage/transmission" = {
        "d" = {
          mode = "0750";
          user = "transmission";
          group = "transmission";
        };
      };
    };
  };

  services.restic.commonPaths = [
    "/storage/transmission"
  ];

  sops.secrets."transmission-rpc-password" = {
    owner = "transmission";
    group = "transmission";
    mode = "0400";
  };

  services.transmission = {
    enable = true;
    dataDir = "/storage/transmission"; # Home directory for the user
    settings = {
      # For a full list of options, see:
      # https://github.com/transmission/transmission/blob/main/docs/settings-spec.md
      "rpc-authentication-required" = true;
      "rpc-username" = "admin";
      "rpc-password" = ''$__file{${config.sops.secrets."transmission-rpc-password".path}}'';
      "rpc-port" = 9091;
      "rpc-whitelist-enabled" = false; # Allow access from any IP, relying on the reverse proxy
      "download-dir" = "/storage/downloads";
      "incomplete-dir-enabled" = true;
      "incomplete-dir" = "/storage/downloads/incomplete";
      "watch-dir-enabled" = true;
      "watch-dir" = "/storage/downloads/watch";
    };
  };

  # The transmission RPC port does not need to be opened in the firewall
  # because we are using a reverse proxy (caddy) to access it.
  # Caddy will listen on 80/443 and forward traffic to the local RPC port.

  services.caddy.virtualHosts."transmission.your-domain.com" = {
    extraConfig = ''reverse_proxy localhost:${
      toString config.services.transmission.settings."rpc-port"
    }'';
  };
}
