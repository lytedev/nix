inputs @ { self, ... }:
let
  daniel = {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.daniel = import ./daniel.nix;
  };
  hms = [
    inputs.home-manager.nixosModules.home-manager
    daniel
  ];
  disko = scheme: disks: [
    inputs.disko.nixosModules.disko
    scheme
    { _module.args.disks = disks; }
  ];
  nixosSystem = modules: (inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      inputs.sops-nix.nixosModules.sops
      ./nixos/common.nix
    ] ++ modules ++ hms;
  });
  diskoNixosSystem = scheme: disks: modules: (nixosSystem ((disko scheme disks) ++ modules));
in
{
  # TODO: disko-fy rascal and beefcake?

  beefcake = nixosSystem [
    ./nixos/beefcake.nix
    inputs.api-lyte-dev.nixosModules.x86_64-linux.api-lyte-dev
  ];

  rascal = nixosSystem [ ./nixos/rascal.nix ];
  musicbox = diskoNixosSystem self.diskoConfigurations.unencrypted [ "/dev/sda" ] [ ./nixos/musicbox.nix ];
  thinker = diskoNixosSystem self.diskoConfigurations.standard [ "/dev/nvme0n1" ] [ ./nixos/thinker.nix ];
  dragon = diskoNixosSystem self.diskoConfigurations.standard [ "/dev/disk/by-uuid/asdf" ] [ ./machines/dragon.nix ];
}
