{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    inherit (self) outputs;
    systems = [
      "x86_64-linux"
    ];

    forAllSystems = nixpkgs.lib.genAttrs systems;
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
