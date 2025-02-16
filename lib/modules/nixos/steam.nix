{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  config = lib.mkIf config.programs.steam.enable { };
}
