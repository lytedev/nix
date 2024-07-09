{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";

  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  inputs.pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";

  outputs = {
    self,
    nixpkgs,
    pre-commit-hooks,
    ...
  }: let
    systems = ["aarch64-linux" "aarch64-darwin" "x86_64-darwin" "x86_64-linux"];
    forSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: (import nixpkgs {inherit system;});
    genPkgs = func: (forSystems (system: func (pkgsFor system)));
  in {
    formatter = genPkgs (pkgs: pkgs.alejandra);

    checks = genPkgs (pkgs: {
      pre-commit-check = pre-commit-hooks.lib.${pkgs.system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
        };
      };
    });

    devShells = genPkgs (pkgs: {
      nix = pkgs.mkShell {
        packages = with pkgs; [nil alejandra];
        inherit (self.outputs.checks.${pkgs.system}.pre-commit-check) shellHook;
      };

      default = self.outputs.devShells.${pkgs.system}.nix;
    });

    # packages = genPkgs (pkgs: import ./pkgs {inherit pkgs;});
    # overlays = import ./overlays self;
    # nixosModules = import ./modules/nixos;
    # homeManagerModules = import ./modules/home-manager;
    # nixosConfigurations = import ./nixos;
    # homeConfigurations = import ./home
    # templates = import ./templates;
  };
}
