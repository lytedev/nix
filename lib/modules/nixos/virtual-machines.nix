{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.virtualisation.libvirtd.enable {
    users.groups.libvirtd.members = [ config.lyte.username ];
  };
}
