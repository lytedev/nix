{ pkgs, ... }:
{
  installer = pkgs.callPackage ./installer.nix { };
  ghostty-terminfo = pkgs.callPackage ./ghostty-terminfo.nix { };
  forgejo-actions-container = pkgs.callPackage ./forgejo-actions-container.nix { };
  hello_world = pkgs.callPackage ./rust/hello_world { };
  hello_world_script = pkgs.writeScriptBin "hello_world_script" (
    builtins.readFile ./rust/hello_world_script/main.rs
  );
  mcpm-aider = pkgs.writeScriptBin "mcpm-aider" (builtins.readFile ./mcp-manager.bash);
  # Thin wrappers around npx for agent tools
  claude-code = pkgs.writeShellApplication {
    name = "claude";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec npx -y @anthropic-ai/claude-code "$@"
    '';
  };
  happy-coder = pkgs.writeShellApplication {
    name = "happy";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec npx -y happy-coder "$@"
    '';
  };
  codex = pkgs.writeShellApplication {
    name = "codex";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec npx -y @openai/codex "$@"
    '';
  };
  claude-to-opencode = pkgs.writeShellApplication {
    name = "claude-to-opencode";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./claude-to-opencode.py} "$@"
    '';
  };
  fbkeyboard = pkgs.callPackage ./fbkeyboard.nix { };
  stevia = pkgs.callPackage ./stevia.nix { };
  cellbroadcastd = pkgs.callPackage ./cellbroadcastd.nix { };
  spacetimedb = pkgs.callPackage ./spacetimedb/package.nix { };
  kanidm = pkgs.callPackage ./kanidm/package.nix { };
}
