{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs?rev=2c7f3c0fb7c08a0814627611d9d7d45ab6d75335";
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
