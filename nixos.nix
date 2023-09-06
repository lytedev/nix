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
  nixosSystem = modules: inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [ ./nixos/common.nix ] ++ modules;
  };
in
{
  beefcake = nixosSystem [
    inputs.sops-nix.nixosModules.sops
    ./machines/beefcake.nix
    inputs.api-lyte-dev.nixosModules.x86_64-linux.api-lyte-dev
  ] ++ hms;

  musicbox = nixosSystem (disko self.diskoConfigurations.unencrypted [ "/dev/sda" ]) ++ [
    ./machines/musicbox.nix
  ] ++ hms;

  thinker = nixosSystem (disko self.diskoConfigurations.standard [ "/dev/nvme0n1" ]) ++ [
    ./machines/thinker.nix
    inputs.sops-nix.nixosModules.sops
  ] ++ hms;
}
