{
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
    pkgsFor = system: import nixpkgs {inherit system;};
    genPkgs = f: (f (forSystems pkgsFor));
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

    devShell = genPkgs (pkgs:
      pkgs.mkShell {
        buildInputs = with pkgs; [nil alejandra];
        inherit (self.outputs.checks.${pkgs.system}.pre-commit-check) shellHook;
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
