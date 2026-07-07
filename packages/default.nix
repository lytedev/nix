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
  fbkeyboard = pkgs.callPackage ./fbkeyboard.nix { };
  stevia = pkgs.callPackage ./stevia.nix { };
  cellbroadcastd = pkgs.callPackage ./cellbroadcastd.nix { };
  spacetimedb = pkgs.callPackage ./spacetimedb/package.nix { };
  kanidm = pkgs.callPackage ./kanidm/package.nix { };
  text-to-mic = pkgs.callPackage ./text-to-mic.nix { };
  wden = pkgs.callPackage ./wden.nix { };
  deploy-esp32 = pkgs.callPackage ./esphome/esp32-s3-box-3/deploy.nix { };
  # Shadows nixpkgs' orca-slicer (blank 3D viewport on this system) with the
  # working upstream AppImage. See ./orca-slicer.nix.
  orca-slicer = pkgs.callPackage ./orca-slicer.nix { };
}
