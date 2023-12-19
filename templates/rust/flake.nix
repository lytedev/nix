{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs?rev=e4ad989506ec7d71f7302cc3067abd82730a4beb";
  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux"];
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          inherit system;
          pkgs = import nixpkgs {inherit system;};
        });
  in {
    devShells = forEachSupportedSystem ({
      pkgs,
      system,
    }: {
      rust-development = pkgs.mkShell {
        buildInputs = with pkgs; [
          cargo
          rustc
          rustfmt
          rustPackages.clippy
          rust-analyzer
        ];
      };

      default = forEachSupportedSystem ({system, ...}: self.outputs.${system}.rust-development);
    });
  };
}
