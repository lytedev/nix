{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = {
    self,
    git-hooks,
    nixpkgs,
  }: let
    inherit (self) outputs;
    systems = ["aarch64-linux" "aarch64-darwin" "x86_64-darwin" "x86_64-linux"];
    forSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: (import nixpkgs {inherit system;}).extend outputs.overlays.default;
    genPkgs = func: (forSystems (system: func (pkgsFor system)));
  in {
    checks = genPkgs (pkgs: {
      git-hooks = git-hooks.lib.${pkgs.system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
          cargo-check.enable = true;
          clippy = {
            enable = true;
            packageOverrides.cargo = pkgs.cargo;
            packageOverrides.clippy = pkgs.rustPackages.clippy;
          };
          rustfmt = {
            enable = true;
            packageOverrides.rustfmt = pkgs.rustfmt;
          };
        };
      };
    });

    packages = genPkgs (pkgs: {
      my-package = pkgs.rustPlatform.buildRustPackage {
        pname = "my-package";
        version = "0.1.0";

        /*
        nativeBuildInputs = with pkgs; [
        pkg-config
        clang
        ];

        buildInputs = with pkgs; [
        ];
        */

        src = ./.;
        hash = pkgs.lib.fakeHash;
        cargoHash = "sha256-W7VQlMktGsRPQL9VGVmxYV6C5u2eJ48S7eTpOM+3n8U=";

        RUSTFLAGS = pkgs.lib.optionalString pkgs.stdenv.isLinux "-C link-arg=-fuse-ld=mold";
      };

      default = outputs.packages.${pkgs.system}.my-package;
    });

    devShells = genPkgs (pkgs: {
      default = pkgs.mkShell {
        inherit (self.checks.${pkgs.system}.git-hooks) shellHook;
        inputsFrom = [outputs.packages.${pkgs.system}.default];
        packages = with pkgs; [
          rustPackages.clippy
          rust-analyzer
          rustfmt
          lldb
        ];
      };
    });

    overlays = {
      default = final: prev: {};
    };

    formatter = genPkgs (p: p.alejandra);
  };
}
