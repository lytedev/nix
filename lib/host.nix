inputs:
let
  baseHost =
    {
      nixpkgs,
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
            hardware = inputs.hardware.outputs.nixosModules;
            diskoConfigurations = inputs.self.outputs.diskoConfigurations;
          };
          modules = [
            {
              imports = extraImports;
              nixpkgs.overlays = extraOverlays;
            }
            inputs.determinate.nixosModules.default
          ]
          ++ extraModules
          ++ [
            inputs.self.outputs.nixosModules.default
            (import path)
          ];
        })
      )
    );
  stable = { inherit (inputs) nixpkgs; };
  unstable = {
    nixpkgs = inputs.nixpkgs-unstable;
  };
  # Mobile device host helper
  mobileHost =
    device: path:
    {
      system ? "aarch64-linux",
    }:
    unstable.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
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
        # Enable UHID for BLE HID keyboard support
        (
          { pkgs, lib, ... }:
          let
            baseKernel = pkgs.callPackage "${inputs.mobile-nixos}/devices/${device}/kernel" {
              inherit (pkgs) mobile-nixos fetchFromGitea fetchpatch;
            };
            kernelWithUhid = baseKernel.overrideAttrs (oldAttrs: {
              postConfigure = (oldAttrs.postConfigure or "") + ''
                echo "Enabling CONFIG_UHID for BLE HID support..."
                echo "CONFIG_UHID=y" >> $buildRoot/.config
                make $makeFlags "''${makeFlagsArray[@]}" oldconfig
              '';
            });
          in
          {
            mobile.boot.stage-1.kernel.package = lib.mkOverride 1 kernelWithUhid;
          }
        )
        # mobile-nixos specific settings
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

            mobile.boot.stage-1.ssh.enable = cfg.stage1Ssh;

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
    }
  );
}
