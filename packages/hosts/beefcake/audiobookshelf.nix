{ config, lib, ... }:
{
  systemd.tmpfiles.settings = {
    "10-audiobookshelf" = {
      "/storage/audiobookshelf" = {
        "d" = {
          mode = "0770";
          user = "audiobookshelf";
          group = "wheel";
        };
      };
      "/storage/audiobookshelf/audiobooks" = {
        "d" = {
          mode = "0770";
          user = "audiobookshelf";
          group = "wheel";
        };
      };
      "/storage/audiobookshelf/podcasts" = {
        "d" = {
          mode = "0770";
          user = "audiobookshelf";
          group = "wheel";
        };
      };
    };
  };
  users.groups.audiobookshelf = { };
  users.users.audiobookshelf = {
    isSystemUser = true;
    group = "audiobookshelf";
  };
  services.audiobookshelf = {
    enable = true;
    dataDir = "/storage/audiobookshelf";
    port = 8523;
  };
  systemd.services.audiobookshelf.serviceConfig = {
    WorkingDirectory = lib.mkForce config.services.audiobookshelf.dataDir;
    StateDirectory = lib.mkForce config.services.audiobookshelf.dataDir;
    Group = "audiobookshelf";
    User = "audiobookshelf";
  };
  services.caddy.virtualHosts."audio.lyte.dev" = {
    extraConfig = ''reverse_proxy :${toString config.services.audiobookshelf.port}'';
  };
}
