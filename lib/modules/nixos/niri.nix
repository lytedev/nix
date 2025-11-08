flakeInputs:
let
  inherit (flakeInputs.self.flakeLib) conditionalOutOfStoreSymlink;
in
{
  # options,
  pkgs,
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
    (
      { ... }:
      {
        home-manager.users.daniel = {
          imports = [
            (
              { config, ... }:
              {
                home.file."${config.xdg.configHome}/niri" = {
                  source = conditionalOutOfStoreSymlink config /etc/nix/flake/lib/modules/home/niri ../home/niri;
                };
              }
            )
          ];
        };
      }
    )
  ];

  config = lib.mkIf (config.lyte.desktop.enable && (config.lyte.desktop.environment == "niri")) {
    nixpkgs.overlays = [ flakeInputs.niri.overlays.niri ];
    programs.niri.enable = builtins.trace "niri enabled" true;
    environment.systemPackages = with pkgs; [ fuzzel ];
  };
}
