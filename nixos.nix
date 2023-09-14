inputs @ { self, ... }:
let
  daniel = system: {
    home-manager.users.daniel = {
      nixpkgs.overlays = [
        (final: prev: {
          helix = prev.helix // inputs.helix.packages.${system}.helix;
          rtx = prev.rtx // inputs.rtx.packages.${system}.rtx;
        })
      ];
      imports = [ ./home/user.nix ./home/linux.nix ];
    };
  };
  hms = system: [
    inputs.home-manager.nixosModules.home-manager
    (daniel system)
  ];
  disko = scheme: disks: [
    inputs.disko.nixosModules.disko
    scheme
    { _module.args.disks = disks; }
  ];
  nixosSystem = system: modules: (inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs system; };
    modules = [
      inputs.sops-nix.nixosModules.sops
      ./nixos/common.nix
    ] ++ modules ++ hms system;
  });
  diskoNixosSystem = system: scheme: disks: modules: (nixosSystem system ((disko scheme disks) ++ modules));
in
{
  # TODO: disko-fy rascal and beefcake?

  beefcake = nixosSystem [
    ./nixos/beefcake.nix
    inputs.api-lyte-dev.nixosModules.x86_64-linux.api-lyte-dev
  ];

  rascal = nixosSystem [ ./nixos/rascal.nix ];

  musicbox = diskoNixosSystem "x86_64-linux" self.diskoConfigurations.unencrypted [ "/dev/sda" ] [ ./nixos/musicbox.nix ];
  thinker = diskoNixosSystem "x86_64-linux" self.diskoConfigurations.standard [ "/dev/nvme0n1" ] [ ./nixos/thinker.nix ];
  # dragon = diskoNixosSystem self.diskoConfigurations.standard [ "/dev/disk/by-uuid/asdf" ] [ ./nixos/dragon.nix ];
}
