inputs:
let
  inherit (inputs.self.flakeLib)
    host
    stableHost
    steamdeckHost
    mobileHost
    baseHost
    stable
    ;
in
{
  # stable + the impermanence module (flag-gated in beefcake/impermanence.nix;
  # a no-op until lyte.impermanence.enable is flipped)
  beefcake = baseHost (
    stable // { extraModules = [ inputs.impermanence.nixosModules.impermanence ]; }
  ) ./beefcake.nix { };
  dragon = host ./dragon.nix { };
  # Like `host` (baseHost unstable) but with the standalone deckmode module for the
  # jump-in/out gamescope gaming mode. Kept out of the shared modules since it's a
  # foxtrot-specific opt-in for now.
  foxtrot = baseHost {
    nixpkgs = inputs.nixpkgs-unstable;
    extraModules = [ inputs.deckmode.nixosModules.default ];
  } ./foxtrot.nix { };
  thinker = host ./thinker.nix { };
  # htpc = host ./htpc.nix { }; # broken: rtl8812au marked broken upstream
  # htpc2 = stableHost ./htpc2.nix { };
  router = stableHost ./router.nix { };
  bigtower = host ./bigtower.nix { };
  rascal = stableHost ./rascal.nix { };
  pebble = stableHost ./pebble.nix { };
  flipflop = host ./flipflop.nix { };
  flipflop2 = host ./flipflop2.nix { };
  babyflip = host ./babyflip { };
  flab = host ./flab.nix { };
  sanctuary = host ./sanctuary.nix { };

  steamdeck = steamdeckHost ./steamdeck.nix { };
  steamdeckoled = steamdeckHost ./steamdeckoled.nix { };
  # pinephone = mobileHost "pine64-pinephone" ./pinephone.nix { }; # temporarily disabled

  pv23 = baseHost (
    stable
    // {
      extraModules = [
        (inputs.self.diskoConfigurations.unencrypted {
          disk = "/dev/sda";
          rootDatasetEncrypt = false;
        })
      ];
    }
  ) ./generic.nix { };

  vmTestbed =
    let
      nixpkgs = inputs.nixpkgs-unstable;
    in
    baseHost {
      inherit nixpkgs;
      extraModules = [
        (inputs.self.diskoConfigurations.zfsEncryptedUser {
          fullDiskDevicePath = "/dev/vda";
          diskName = "vmtestbed";
          espSize = "256M";
          rootDatasetKeyText = "yoyoyoyo";
          rootDatasetKeyLocation = "file:///tmp/secret.key";
        })
        {
          users.users.root.password = "root";
          system.stateVersion = "25.05";
          networking.hostName = "lytevmtestbed";
          networking.networkmanager.enable = false;

          boot = {
            loader = {
              efi.canTouchEfiVariables = true;
              systemd-boot.enable = true;
            };
          };

          # head -c4 /dev/urandom | od -A none -t x4
          networking.hostId = "5c4fc42c";

          lyte.shell.enable = false;
          lyte.desktop.enable = false;
          # shell and desktop already disabled above
        }
      ];
    } ./empty.nix { };

  liveImage = baseHost rec {
    nixpkgs = inputs.nixpkgs-unstable;
    extraModules = [
      (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
      {
        system.stateVersion = "25.05";
        networking.hostName = "live-nixos-lyte";
        networking.networkmanager.enable = nixpkgs.lib.mkForce true;

        lyte.shell.enable = true;
        lyte.desktop.enable = true;
        # shell and desktop already enabled above
      }
    ];
  } ./live.nix { };

  # arm-dragon = host ./dragon.nix { system = "aarch64-linux"; };
}
