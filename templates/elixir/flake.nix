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

    systems = [
      "aarch64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    forAllSystems = nixpkgs.lib.genAttrs systems;

    nixpkgsFor = system: import nixpkgs {inherit system;};
  in {
    packages = forAllSystems (system: let
      pkgs = nixpkgsFor system;

      inherit (pkgs) beamPackages;
      inherit (beamPackages) mixRelease fetchMixDeps;

      version = "0.1.0";
      src = ./.;
      pname = "api.lyte.dev";
    in {
      # this-package = mixRelease {
      #   inherit pname version src;
      #   mixFodDeps = fetchMixDeps {
      #     inherit version src;
      #     pname = "mix-deps-${pname}";
      #     hash = pkgs.lib.fakeSha256;
      #   };
      #   buildInputs = with pkgs; [sqlite];
      #   HOME = "$(pwd)";
      #   MIX_XDG = "$HOME";
      # };

      # default = outputs.packages.${system}.this-package;
    });

    devShells = forAllSystems (system: let
      pkgs = nixpkgsFor system;
      erlang = pkgs.beam.packages.erlang_26;
      elixir = erlang.elixir_1_16;
    in {
      default = pkgs.mkShell {
        shellHook = "export LOCALE_ARCHIVE=/usr/lib/locale/locale-archive";
        buildInputs = with pkgs; [
          inotify-tools
          erlang_26
          erlang
          elixir-ls
          elixir
        ];
      };
    });
  };
}
