{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf (config.lyte.desktop.enable && config.lyte.desktop.plasma.enable) {
    dconf.enable = true;
  };
}
