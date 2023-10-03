inputs @ {self, ...}: let
  daniel = system: {
    home-manager.users.daniel = {
      imports = [./home/user.nix ./home/linux.nix];
    };
  };
  hms = system: [
    inputs.home-manager.nixosModules.home-manager
    (daniel system)
  ];
  disko = args @ {scheme, ...}: [
    inputs.disko.nixosModules.disko
    self.diskoConfigurations.${scheme}
    {_module.args = args;}
  ];
  nixosSystem = system: modules: (inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {inherit inputs system;};
    modules =
      [
        inputs.sops-nix.nixosModules.sops
        ./nixos/common.nix
      ]
      ++ modules
      ++ hms system;
  });
in {
  # TODO: disko-fy rascal and beefcake?

  beefcake = nixosSystem "x86_64-linux" [
    ./nixos/beefcake.nix
    inputs.api-lyte-dev.nixosModules.x86_64-linux.api-lyte-dev
  ];

  rascal = nixosSystem "x86_64-linux" [./nixos/rascal.nix];

  musicbox = nixosSystem "x86_64-linux" (disko
    {
      scheme = "unencrypted";
      disks = ["/dev/sda"];
    }
    ++ [./nixos/musicbox.nix]);

  thinker = nixosSystem "x86_64-linux" (disko
    {
      scheme = "thinker";
      disks = ["/dev/nvme0n1"];
    }
    ++ [./nixos/thinker.nix]);

  dragon = nixosSystem "x86_64-linux" (disko
    {
      scheme = "standard";
      disks = ["/dev/nvme0n1"];
    }
    ++ [./nixos/dragon.nix]);
}
