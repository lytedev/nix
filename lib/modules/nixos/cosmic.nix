{
  options,
  pkgs,
  lib,
  config,
  ...
}:
{
  config = lib.mkIf (config.lyte.desktop.enable && config.lyte.desktop.cosmic.enable) {
    services.displayManager.cosmic-greeter.enable = true;
    services.desktopManager.cosmic.enable = true;
  };
}
