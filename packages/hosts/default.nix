inputs:
let
  inherit (inputs.self.flakeLib)
    host
    stableHost
    steamdeckHost
    baseHost
    stable
    ;
in
{
  beefcake = stableHost ./beefcake.nix { };
  dragon = host ./dragon.nix { };
  foxtrot = host ./foxtrot.nix { };
  thinker = host ./thinker.nix { };
  htpc = stableHost ./htpc.nix { };
  # htpc2 = stableHost ./htpc2.nix { };
  router = stableHost ./router.nix { };
  bigtower = stableHost ./bigtower.nix { };
  rascal = stableHost ./rascal.nix { };
  flipflop = host ./flipflop.nix { };
  flipflop2 = host ./flipflop2.nix { };
  babyflip = host ./babyflip.nix { };

  steamdeck = steamdeckHost ./steamdeck.nix { };
  steamdeckoled = steamdeckHost ./steamdeckoled.nix { };

  pv23 = baseHost (
    stable
    // {
      extraModules = [
        (inputs.self.diskoConfigurations.unencrypted { disk = "/dev/sda"; })
      ];
    }
  ) ./generic.nix;

  liveImage = baseHost rec {
    nixpkgs = inputs.nixpkgs-unstable;
    home-manager = inputs.home-manager-unstable;
    extraModules = [
      (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
      {
        system.stateVersion = "25.05";
        networking.hostName = "live-nixos-lyte";
        networking.networkmanager.enable = false;

        lyte.shell.enable = true;
        lyte.desktop.enable = true;
        home-manager.users.daniel = {
          lyte.shell.enable = true;
          lyte.desktop.enable = true;
        };
      }
    ];
  } ./live.nix { };

  # arm-dragon = host ./dragon.nix { system = "aarch64-linux"; };
}
