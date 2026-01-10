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
        # Enable UHID for BLE HID keyboard support
        # The mobile-nixos kernel config doesn't have this enabled by default
        # Use pkgs.mobile-nixos (from the mobile-nixos overlay) to build the kernel with UHID
        (
          { pkgs, lib, ... }:
          let
            # Build the kernel using mobile-nixos kernel-builder with UHID support
            baseKernel = pkgs.callPackage "${inputs.mobile-nixos}/devices/${device}/kernel" {
              inherit (pkgs) mobile-nixos fetchFromGitea fetchpatch;
            };
            kernelWithUhid = baseKernel.overrideAttrs (oldAttrs: {
              postConfigure = (oldAttrs.postConfigure or "") + ''
                # Enable UHID for BLE HID (keyboard) support
                echo "Enabling CONFIG_UHID for BLE HID support..."
                echo "CONFIG_UHID=y" >> $buildRoot/.config
                # Re-run oldconfig to process the new option
                make $makeFlags "''${makeFlagsArray[@]}" oldconfig
              '';
            });
          in
          {
            # Override the mobile-nixos kernel package with our modified version
            mobile.boot.stage-1.kernel.package = lib.mkOverride 1 kernelWithUhid;
          }
        )
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
