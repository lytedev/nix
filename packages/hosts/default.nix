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
  beefcake = stableHost ./beefcake.nix { };
  dragon = host ./dragon.nix { };
  foxtrot = host ./foxtrot.nix { };
  thinker = host ./thinker.nix { };
  # htpc = host ./htpc.nix { }; # broken: rtl8812au marked broken upstream
  # htpc2 = stableHost ./htpc2.nix { };
  router = stableHost ./router.nix { };
  bigtower = stableHost ./bigtower.nix { };
  rascal = stableHost ./rascal.nix { };
  flipflop = host ./flipflop.nix { };
  flipflop2 = host ./flipflop2.nix { };
  babyflip = host ./babyflip { };
  flab = host ./flab.nix { };

  steamdeck = steamdeckHost ./steamdeck.nix { };
  steamdeckoled = steamdeckHost ./steamdeckoled.nix { };
  pinephone = mobileHost "pine64-pinephone" ./pinephone.nix { };

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
  ) ./generic.nix;

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
