{
  # Prototypes for the beefcake impermanence + blue/green design.
  # See ../../lib/doc/beefcake-impermanence-blue-green.md §7.
  #
  # Deliberately a standalone flake (own lock) so the main flake's eval and CI
  # are untouched; nixpkgs is pinned to the same rev the main flake feeds
  # nixosSystem (667d5cf = what beefcake runs) for cache hits.
  description = "beefcake impermanence + blue/green prototypes (run on dragon)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/667d5cf1c59585031d743c78b394b0a647537c35";
    impermanence.url = "github:nix-community/impermanence";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      impermanence,
      sops-nix,
      disko,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      checks.${system} = {
        # P1a: impermanence *semantics* — ephemeral root, /persist survives,
        # sops decrypts on a wiped root, postgres + DynamicUser state intact.
        semantics = import ./semantics-test.nix { inherit pkgs impermanence sops-nix; };
        # P2: blue/green *handoff* — two guests sequentially own a shared
        # disk-backed ZFS pool (the zstorage stand-in); cutover + rollback.
        handoff = import ./handoff-test.nix { inherit pkgs; };
        # P3: Model B storage primitives — postgres on ext4-on-zvol, live
        # snapshot+clone opened by a second instance (validation), two-way
        # isolation, clone discard, share-dataset xattr/acl semantics.
        modelb-storage = import ./modelb-storage-test.nix { inherit pkgs; };
      };

      # P1b: the real *mechanism* — ZFS root + @blank rollback via a
      # systemd-initrd unit, in a disko-built image booted twice under qemu.
      nixosConfigurations.rollback = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          ./rollback-config.nix
        ];
      };

      packages.${system} = {
        rollback-demo = import ./rollback-demo.nix {
          inherit pkgs;
          rollbackSystem = self.nixosConfigurations.rollback;
        };
      };

      apps.${system}.rollback-demo = {
        type = "app";
        program = "${self.packages.${system}.rollback-demo}/bin/rollback-demo";
      };
    };
}
