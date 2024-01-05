{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs?rev=bd645e8668ec6612439a9ee7e71f7eac4099d4f6";
  outputs = {
    self,
    nixpkgs,
  }: let
    inherit (self) outputs;
    supportedSystems = ["x86_64-linux"];
    forEachSupportedSystem = nixpkgs.lib.genAttrs supportedSystems;
  in {
    devShells = forEachSupportedSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      rust-dev = pkgs.mkShell {
        buildInputs = with pkgs; [
          cargo
          rustc
          rustfmt
          rustPackages.clippy
          rust-analyzer
        ];
      };

      default = outputs.devShells.${system}.rust-dev;
    });
  };
}
