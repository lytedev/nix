{
  inputs = {
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    pre-commit-hooks,
    ...
  }: let
    inherit (self) outputs;

    systems = [
      "aarch64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    checks = forAllSystems (system: {
      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
        };
      };
    });

    devShell = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      pkgs.mkShell {
        buildInputs = with pkgs; [nil];
        inherit (outputs.checks.${system}.pre-commit-check) shellHook;
      });

    # packages = forAllSystems (system: import ./pkgs {pkgs = nixpkgs.legacyPackages.${system};});
    # overlays = import ./overlays self;
    # nixosModules = import ./modules/nixos;
    # homeManagerModules = import ./modules/home-manager;
    # nixosConfigurations = import ./nixos;
    # homeConfigurations = import ./home
    # templates = import ./templates;
  };
}
