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
      taplo # for editing toml
      convco # commit message linter
      rustPackages.clippy # rust linter
      rust-analyzer # rust language server
      rustfmt # rust formatter
      nixd # nix language server
      lld # wasm linker
      lldb # debugger
    ];
  };
}
