{
  self,
  pkgs,
  ...
}:
let
  inherit (pkgs) system;
in
{
  default = pkgs.mkShell {
    inherit (self.checks.${system}.git-hooks) shellHook;
    inputsFrom = [ self.packages.${system}.default ];
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
}
