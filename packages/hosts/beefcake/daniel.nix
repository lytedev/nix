{
  # daniel augments
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
      "family"
    ];
  };
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
