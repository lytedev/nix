{ pkgs, ... }:
{
  installer = pkgs.callPackage ./installer.nix { };
  ghostty-terminfo = pkgs.callPackage ./ghostty-terminfo.nix { };
  forgejo-actions-container = pkgs.callPackage ./forgejo-actions-container.nix { };
  hello_world = pkgs.callPackage ./rust/hello_world { };
  hello_world_script = pkgs.writeScriptBin "hello_world_script" (
    builtins.readFile ./rust/hello_world_script/main.rs
  );
  vibe = pkgs.writeScriptBin "vibe" (builtins.readFile ./vibe.bash);
  mcpm-aider = pkgs.writeScriptBin "mcpm-aider" (builtins.readFile ./mcp-manager.bash);
  claude-code = pkgs.callPackage ./claude-code.nix { };
  happy-coder = pkgs.callPackage ./happy-coder.nix { };
  fbkeyboard = pkgs.callPackage ./fbkeyboard.nix { };
  stevia = pkgs.callPackage ./stevia.nix { };
  cellbroadcastd = pkgs.callPackage ./cellbroadcastd.nix { };
}
