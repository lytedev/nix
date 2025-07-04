inputs:
{ lib, config, ... }:
{
  imports = [ inputs.niri.nixosModules.niri ];
  config = lib.mkIf (config.lyte.desktop.enable && (config.lyte.desktop.environment == "niri")) {
    nixpkgs.overlays = [ inputs.niri.overlays.niri ];
    programs.niri.enable = true;

    # TODO: bar
    # TODO: notifications (mako?)
    # TODO: launcher (fuzzel?)
    # TODO: probably lots of other stuff
  };
}
