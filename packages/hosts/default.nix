inputs:
let
  inherit (inputs.self.flakeLib)
    host
    stableHost
    steamdeckHost
    baseHost
    ;
in
{
  beefcake = stableHost ./beefcake.nix { };
  dragon = host ./dragon.nix { };
  foxtrot = host ./foxtrot.nix { };
  thinker = host ./thinker.nix { };
  htpc = stableHost ./htpc.nix { };
  router = stableHost ./router.nix { };
  bigtower = stableHost ./bigtower.nix { };
  rascal = stableHost ./rascal.nix { };
  flipflop = host ./flipflop.nix { };

  steamdeck = steamdeckHost ./steamdeck.nix { };
  steamdeckoled = steamdeckHost ./steamdeckoled.nix { };

  generic-headless = stableHost ./generic-headless.nix { };
  generic = stableHost ./generic.nix { };

  liveIso = baseHost rec {
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
  } ./iso.nix { };

  # arm-dragon = host ./dragon.nix { system = "aarch64-linux"; };
}
