{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    api-lyte-dev.url = "git+ssh://gitea@git.lyte.dev/lytedev/api.lyte.dev.git";
    home-manager.url = "github:nix-community/home-manager/release-23.05";
    disko.url = "github:nix-community/disko/master";
    sops-nix.url = "github:Mic92/sops-nix";
    helix.url = "github:helix-editor/helix";
    rtx.url = "github:jdx/rtx";
  };

  outputs = inputs @ { self, ... }: {
    diskoConfigurations = import ./disko.nix;
    homeConfigurations = import ./home.nix inputs;
    nixosConfigurations = import ./nixos.nix inputs;
  };
}
