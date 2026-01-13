{ config, ... }:
{
  k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    dataDir = "/storage/k3s";
    disableTraefik = true;
    tokenFile = config.sops.secrets.k3s-token.path;
    openFirewall = true;
    extraFlags = [
      "--tls-san=beefcake"
      "--tls-san=beefcake.lan"
    ];
  };

  systemd.tmpfiles.settings."10-k3s" = {
    "/storage/k3s" = {
      d = {
        mode = "0700";
        user = "root";
        group = "root";
      };
    };
  };

  sops.secrets.k3s-token.mode = "0400";
}
