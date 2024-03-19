{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    inherit (self) outputs;
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"

      "x86_64-darwin"
      "aarch64-darwin"
    ];

    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  in {
    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = outputs.devShells.${system}.godot;
      godot = pkgs.mkShell {
        buildInputs = with pkgs; [godot_4 gdtoolkit];
        shellHook = ''
          echo -e "\e[0;30m\e[43m Use 'godot4 -e' to run the editor for this project. \e[0;30m\e[0m"
        '';
      };
    });
  };
}
