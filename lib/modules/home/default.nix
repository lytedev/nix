{ self, slippi, ... }@inputs:
let
  inherit (self) outputs;
  inherit (outputs) homeManagerModules;
  inherit (self.flakeLib) conditionalOutOfStoreSymlink;

  # Auto-import all .nix files in this directory except default.nix
  dir = builtins.readDir ./.;
  nixFiles = builtins.filter (name: name != "default.nix" && builtins.match ".*\\.nix" name != null) (
    builtins.attrNames dir
  );

  # Import a module file, passing extra args if needed
  importModule =
    name:
    let
      path = ./. + "/${name}";
      moduleName = builtins.replaceStrings [ ".nix" ] [ "" ] name;
      module = import path;
    in
    # Some modules need extra arguments
    if moduleName == "niri" then
      module { inherit inputs conditionalOutOfStoreSymlink; }
    else if moduleName == "desktop" then
      module { inherit homeManagerModules conditionalOutOfStoreSymlink; }
    else if moduleName == "helix" then
      module inputs
    else
      module;

  # Build attribute set of all modules
  autoModules = builtins.listToAttrs (
    map (name: {
      name = builtins.replaceStrings [ ".nix" ] [ "" ] name;
      value = importModule name;
    }) nixFiles
  );

in
autoModules
// {
  default =
    {
      lib,
      ...
    }:
    {
      imports = with homeManagerModules; [
        slippi.homeManagerModules.default
        shell
        fish
        helix
        git
        jujutsu
        zellij
        htop
        linux
        sshconfig
        senpai
        iex
        cargo
        desktop
        gnome
        cosmic
        niri
        push-to-talk
        mobile
      ];

      config = {
        slippi-launcher.enable = lib.mkDefault false;
      };
    };
}
