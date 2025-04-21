{
  systemd.tmpfiles.settings = {
    "10-actual" = {
      "/storage/actual" = {
        "d" = {
          mode = "0750";
          user = "root";
          group = "family";
        };
      };
    };
  };
  services.restic.commonPaths = [
    "/storage/actual"
  ];

  virtualisation.oci-containers = {
    containers.actual = {
      image = "ghcr.io/actualbudget/actual-server:25.2.1";
      autoStart = true;
      ports = [ "5006:5006" ];
      volumes = [ "/storage/actual:/data" ];
    };
  };

  services.caddy.virtualHosts."finances.h.lyte.dev" = {
    extraConfig = ''reverse_proxy :5006'';
  };
}
