{
  services.restic.commonPaths = [ "/var/lib/heisenbridge" ];

  services.heisenbridge = {
    enable = true;
    homeserver = "http://localhost:6167";
    owner = "@daniel:lyte.dev";
  };

  # heisenbridge module sets itself to start before matrix-synapse.service,
  # but we use tuwunel -- ensure it starts after tuwunel is up
  systemd.services.heisenbridge = {
    after = [ "tuwunel.service" ];
    wants = [ "tuwunel.service" ];
  };
}
