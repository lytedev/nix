inputs:
let
  inherit (inputs) self;
  inherit (self.outputs) homeConfigurations homeManagerModules;
in
{
  default = inputs.home-manager-unstable.lib.homeManagerConfiguration {
    pkgs = (import inputs.nixpkgs-unstable { system = "x86_64-linux"; }).extend self.overlays.forSelf;

    modules = with homeManagerModules; [
      (
        { lib, ... }:
        {
          home = {
            stateVersion = "25.11";
            homeDirectory = "/home/daniel/.home";
          };
          programs.home-manager.enable = true;

          # install using the OS's package manager instead
          programs.firefox.enable = false;
          programs.ghostty.enable = false;
          programs.noctalia-shell.enable = lib.mkForce false;

          lyte = {
            shell.enable = true;
            desktop = {
              enable = true;
              niri.enable = true;
            };
          };
        }
      )
      daniel
      default
    ];

  };
  daniel = homeConfigurations.default;
}
