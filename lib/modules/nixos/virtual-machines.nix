{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.virtualisation.libvirtd.enable {
    users.users.daniel.extraGroups = [ "libvirtd" ];
  };
}
