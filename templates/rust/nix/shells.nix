{
  self,
  pkgs,
  ...
}: let
  inherit (pkgs) system;
in rec {
  my-package-dev = pkgs.mkShell {
    inherit (self.checks.${system}.git-hooks) shellHook;
    inputsFrom = [self.packages.${system}.my-package];
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
  default = my-package-dev;
}
