{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    utils.url = "github:gytis-ivaskevicius/flake-utils-plus";
    # nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-channels/nixos-unstable";
    api-lyte-dev.url = "git+ssh://gitea@git.lyte.dev/lytedev/api.lyte.dev.git";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      # inputs.utils.follows = "utils";
    };

    disko.url = "github:nix-community/disko/master";
    sops-nix.url = "github:Mic92/sops-nix";
    # TODO: hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = inputs @ { self, ... }: {
    diskoConfigurations = import ./disko.nix;
    homeConfigurations = import ./home.nix inputs;
    nixosConfigurations = import ./nixos.nix inputs;
  };
}
