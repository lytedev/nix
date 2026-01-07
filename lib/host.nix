inputs:
let
  baseHost =
    {
      nixpkgs,
      home-manager,
      nixosSystem ? nixpkgs.lib.nixosSystem,
      extraModules ? [ ],
      extraOverlays ? [ ],
      extraImports ? [ ],
      ...
    }:
    (
      path:
      (
        {
          system ? "x86_64-linux",
        }:
        (nixosSystem {
          inherit system;
          specialArgs = {
            inherit home-manager;
            hardware = inputs.hardware.outputs.nixosModules;
            diskoConfigurations = inputs.self.outputs.diskoConfigurations;
          };
          modules = [
            {
              imports = extraImports;
              nixpkgs.overlays = extraOverlays;
            }
          ]
          ++ extraModules
          ++ [
            inputs.self.outputs.nixosModules.default
            (import path)
          ];
        })
      )
    );
  stable = { inherit (inputs) nixpkgs home-manager; };
  unstable = {
    nixpkgs = inputs.nixpkgs-unstable;
    home-manager = inputs.home-manager-unstable;
  };
  # Mobile device host helper
  # device: mobile-nixos device name (e.g., "pine64-pinephone")
  # path: path to the host configuration
  # system: optional, defaults to aarch64-linux (most mobile devices)
  mobileHost =
    device: path:
    {
      system ? "aarch64-linux",
    }:
    unstable.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        home-manager = inputs.home-manager-unstable;
        hardware = inputs.hardware.outputs.nixosModules;
        diskoConfigurations = inputs.self.outputs.diskoConfigurations;
      };
      modules = [
        (import "${inputs.mobile-nixos}/lib/configuration.nix" {
          inherit device;
        })
        inputs.self.outputs.nixosModules.default
        (import path)
        { nixpkgs.config.allowUnfree = true; }
        # mobile-nixos specific settings (uses lyte.mobile options)
        (
          { config, lib, ... }:
          let
            cfg = config.lyte.mobile;
          in
          lib.mkIf cfg.enable {
            mobile.beautification = {
              silentBoot = cfg.silentBoot;
              splash = true;
            };

            # Stage-1 SSH for early debugging
            mobile.boot.stage-1.ssh.enable = cfg.stage1Ssh;

            # Firmware for modem, wifi, etc.
            mobile.boot.stage-1.firmware = [ config.mobile.device.firmware ];
            hardware.firmware = [ config.mobile.device.firmware ];
          }
        )
      ];
    };
in
{
  inherit
    baseHost
    stable
    unstable
    mobileHost
    ;
  stableHost = baseHost stable;
  host = baseHost unstable;
  steamdeckHost = baseHost (
    unstable
    // {
      extraModules = [
        inputs.jovian.outputs.nixosModules.default
        inputs.self.nixosModules.steamdeck
      ];
      # do NOT manually include the jovian overlay here
    }
  );
}
