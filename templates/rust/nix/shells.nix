{
  self,
  pkgs,
  ...
}: let
  inherit (pkgs) system;
in rec {
  lyrs-dev = pkgs.mkShell {
    inherit (self.checks.${system}.git-hooks) shellHook;
    inputsFrom = [self.packages.${system}.lyrs];
    packages = with pkgs; [
      convco
      rustPackages.clippy
      typescript-language-server
      rust-analyzer
      rustfmt
      nixd
      lldb
    ];
  };
  default = lyrs-dev;
}
