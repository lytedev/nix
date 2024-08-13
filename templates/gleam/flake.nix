{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    systems = ["aarch64-linux" "x86_64-linux" "x86_64-darwin" "aarch64-darwin"];
    forSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: (import nixpkgs {inherit system;}).extend self.outputs.overlays.default;
    genPkgs = func: (forSystems (system: func (pkgsFor system)));
  in {
    overlays.default = final: prev: {
      erlangPackages = prev.beam.packagesWith prev.erlang_27;
      erlang = final.erlangPackages.erlang;
    };
    devShells = genPkgs (pkgs: {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          erlang
          gleam
          rebar3
        ];
      };
    });
  };
}
