{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    inherit (self) outputs;

    supportedSystems = [
      "aarch64-linux"
      "x86_64-linux"

      "x86_64-darwin"
      "aarch64-darwin"
    ];

    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    overlay = final: prev: {
      erlangPackages = prev.beam.packagesWith prev.erlang_26;
      erlang = final.erlangPackages.erlang;
      elixir = final.erlangPackages.elixir_1_16;

      mixRelease = final.erlangPackages.mixRelease.override {
        elixir = final.elixir;
      };
      fetchMixDeps = final.erlangPackages.fetchMixDeps.override {
        elixir = final.elixir;
      };

      elixir-ls = prev.elixir-ls.override {elixir = final.elixir;};
    };

    nixpkgsFor = system: ((import nixpkgs {inherit system;}).extend overlay);
  in {
    packages = forAllSystems (system: let
      pkgs = nixpkgsFor system;

      inherit (pkgs) beamPackages;
      inherit (beamPackages) mixRelease fetchMixDeps;

      version = "0.1.0";
      src = ./.;
      pname = "api.lyte.dev";
    in {
      /*
      this-package = mixRelease {
        inherit pname version src;
        mixFodDeps = fetchMixDeps {
          inherit version src;
          pname = "mix-deps-${pname}";
          hash = pkgs.lib.fakeSha256;
        };
        buildInputs = with pkgs; [sqlite];
        HOME = "$(pwd)";
        MIX_XDG = "$HOME";
      };

      default = outputs.packages.${system}.this-package;
      */
    });

    devShells = forAllSystems (system: let
      pkgs = nixpkgsFor system;
    in {
      default = pkgs.mkShell {
        shellHook = "export LOCALE_ARCHIVE=/usr/lib/locale/locale-archive";
        buildInputs = with pkgs; [
          elixir
          elixir-ls

          inotify-tools
        ];
      };
    });
  };
}
