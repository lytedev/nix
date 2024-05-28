{
  # inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.nixpkgs.url = "github:nixos/nixpkgs?rev=ae34cb9560a578b6354655538e98fb69e8bc8d39";
  outputs = inputs: let
    supportedSystems = ["aarch64-linux" "x86_64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = inputs.nixpkgs.lib.genAttrs supportedSystems;
    overlay = final: prev: {
      erlangPackages = prev.beam.packagesWith prev.erlang_26;
      erlang = final.erlangPackages.erlang;
    };
    nixpkgsFor = system: ((import inputs.nixpkgs {inherit system;}).extend overlay);
  in {
    devShells = forAllSystems (system: let
      pkgs = nixpkgsFor system;
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          erlang
          gleam
        ];
      };
    });
  };
}
/*

# a useful overlay for setting packages to certain versions

overlay = final: prev: {
  # erlangPackages = prev.beam.packagesWith prev.erlang_26;
  # erlang = final.erlangPackages.erlang;
  # elixir = final.erlangPackages.elixir_1_16;

  # mixRelease = final.erlangPackages.mixRelease.override {
  # elixir = final.elixir;
  # };
  # fetchMixDeps = final.erlangPackages.fetchMixDeps.override {
  # elixir = final.elixir;
  # };

  # elixir-ls = prev.elixir-ls.override {elixir = final.elixir;};
};

# have a package

packages = forAllSystems (system: let
  pkgs = nixpkgsFor system;

  # inherit (pkgs) beamPackages;
  # inherit (beamPackages) mixRelease fetchMixDeps;

  version = "0.1.0";
  src = ./.;
  pname = "gleam-project";
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
*/

