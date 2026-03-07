inputs:
let
  hardware = inputs.hardware.outputs.nixosModules;
  diskoConfigurations = inputs.self.outputs.diskoConfigurations;

  # Extract hardwareModules and diskConfig from a host file to generate
  # additional imports. Works with both plain attrsets and function-based
  # modules -- Nix's laziness means the dummy args are never forced as long
  # as hardwareModules/diskConfig are plain values.
  hostImportsFor =
    hostModule:
    let
      raw =
        if builtins.isFunction hostModule then
          hostModule (builtins.mapAttrs (_: _: null) (builtins.functionArgs hostModule))
        else
          hostModule;
      hwNames = raw.hardwareModules or [ ];
      diskName = raw.diskConfig or null;
    in
    (map (name: hardware.${name}) hwNames)
    ++ (if diskName != null then [ diskoConfigurations.${diskName} ] else [ ]);

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
      let
        hostModule = import path;
      in
      (
        {
          system ? "x86_64-linux",
        }:
        (nixosSystem {
          inherit system;
          specialArgs = {
            inherit hardware diskoConfigurations;
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
            hostModule
          ]
          ++ (hostImportsFor hostModule);
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
