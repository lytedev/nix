{
  lib,
  config,
  # pkgs,
  ...
}:
{
  config = lib.mkIf (config.lyte.desktop.enable && config.lyte.desktop.cosmic.enable) {
  };
}
