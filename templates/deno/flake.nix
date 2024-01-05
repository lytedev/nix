{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs?rev=2c7f3c0fb7c08a0814627611d9d7d45ab6d75335";
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
      deno-dev = pkgs.mkShell {
        buildInputs = with pkgs; [
          deno
        ];
      };

      default = outputs.devShells.${system}.deno-dev;
    });
  };
}
