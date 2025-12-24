{ self, ... }:
{ pkgs, ... }:
let
  unfreePkgs = import pkgs.path {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  claude-code = unfreePkgs.callPackage ../claude-code.nix { };
  happy-coder = unfreePkgs.callPackage ../happy-coder.nix { };
in
{
  default = pkgs.mkShell {
    inherit (self.outputs.checks.${pkgs.stdenv.hostPlatform.system}.git-hooks) shellHook;
    packages = with pkgs; [
      colmena
      sops
      nil
      nixd
      nixfmt-rfc-style
      lua-language-server
      nodePackages.bash-language-server
      markdown-oxide
    ];
  };

  agent = pkgs.mkShell {
    packages = [
      claude-code
      happy-coder
    ];
    shellHook = ''
      # happy-coder looks for claude at ~/.local/bin/claude (not in PATH)
      mkdir -p ~/.local/bin
      ln -sf "$(which claude)" ~/.local/bin/claude

      # Use self-hosted happy server
      export HAPPY_SERVER_URL="https://happy.h.lyte.dev"
    '';
  };

  music-production = pkgs.mkShell {
    # TODO: reaper? VSTs like Helm? Neural Amp modeler for guitar?
    # I would love to be able to do basic recording and editing as well as live "performances" with effects chains etc.
  };
}
