{ config, lib, ... }:

let
  cfg = config.lyte.headscale;
in
{
  options.lyte.headscale = {
    usePreAuthKey = lib.mkEnableOption "auto-authenticate to Headscale using a pre-auth key (for servers/always-on devices)";
  };

  config = lib.mkIf cfg.usePreAuthKey {
    sops.secrets.headscale-server-authkey = {
      sopsFile = ../../../secrets/servers/secrets.yml;
    };

    services.tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets.headscale-server-authkey.path;
      extraUpFlags = [
        "--login-server=https://vpn.h.lyte.dev"
        "--reset"
        "--accept-dns"
      ];
    };
  };
}
