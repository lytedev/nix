{
  # daniel augments
  systemd.tmpfiles.settings = {
    "10-daniel" = {
      "/storage/daniel" = {
        "d" = {
          mode = "0700";
          user = "daniel";
          group = "nogroup";
        };
      };
      "/storage/daniel/critical" = {
        "d" = {
          mode = "0700";
          user = "daniel";
          group = "nogroup";
        };
      };
    };
  };
  users.groups.daniel.members = [ "daniel" ];
  users.users.daniel = {
    extraGroups = [
      "wheel" # sudo access
      "caddy" # write access to public static files
      "users" # general users group
      "jellyfin" # write access to jellyfin files
      "audiobookshelf" # write access to audiobookshelf files
      "flanilla" # minecraft server manager
      "forgejo"
    ];
  };
  services.restic.commonPaths = [
    "/storage/daniel"
  ];
  services.postgresql = {
    ensureDatabases = [ "daniel" ];
    ensureUsers = [
      {
        name = "daniel";
        ensureClauses = {
          # superuser = true;
          # createrole = true;
          # createdb = true;
          # bypassrls = true;
        };
        ensureDBOwnership = true;
      }
    ];
  };
}
