flakeInputs:
{
  # options,
  # pkgs,
  lib,
  config,
  ...
}:

{
  # options = {
  #   lyte = {
  #     desktop = {
  #       niri = {
  #       };
  #     };
  #   };
  # };

  imports = [
    # KDE Connect?
    flakeInputs.niri.nixosModules.niri
    # do some things even if we don't actually have the configuration setup
  ];

  config = lib.mkIf (config.lyte.desktop.enable && (config.lyte.desktop.niri.enable)) {
    nixpkgs.overlays = [ flakeInputs.niri.overlays.niri ];
    programs.niri.enable = true;
  };
}
