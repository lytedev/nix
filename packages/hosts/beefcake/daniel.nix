{ config, ... }:
let
  u = config.lyte.username;
in
{
  # daniel augments — kanidm provides the user itself, we just add him to
  # local groups for service-specific access.
  users.groups.wheel.members = [ u ]; # sudo access
  users.groups.caddy.members = [ u ]; # write access to public static files
  users.groups.users.members = [ u ]; # general users group
  users.groups.jellyfin.members = [ u ]; # write access to jellyfin files
  users.groups.audiobookshelf.members = [ u ]; # write access to audiobookshelf files
  users.groups.flanilla.members = [ u ]; # minecraft server manager
  users.groups.forgejo.members = [ u ];
  users.groups.family.members = [ u ];

  services.postgresql = {
    ensureDatabases = [ u ];
    ensureUsers = [
      {
        name = u;
        ensureClauses = { };
        ensureDBOwnership = true;
      }
    ];
  };
}
