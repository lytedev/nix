{ homeManagerModules, conditionalOutOfStoreSymlink }:
{
  pkgs,
  config,
  lib,
  ...
}:
let
  types = lib.types;
in
{
  imports = with homeManagerModules; [
    firefox
    ghostty
  ];
  options = {
    lyte = {
      desktop = {
        enable = lib.mkEnableOption "Enable my default desktop configuration and applications";
        gnome.enable = lib.mkOption {
          default = config.lyte.desktop.enable;
          example = true;
          description = "Enable GNOME desktop configuration and applications";
          type = types.bool;
        };
        plasma.enable = lib.mkEnableOption "Enable Plasma configuration and applications";
        niri.enable = lib.mkEnableOption "Enable Plasma configuration and applications";
        cosmic.enable = lib.mkEnableOption "Enable Cosmic configuration and applications";
        music-production.enable = lib.mkEnableOption "Enable music production configuration";
      };
    };
  };
  config = lib.mkIf config.lyte.desktop.enable {
    home.packages = with pkgs; [
      (
        # allow nixpkgs 24.11 and unstable to both work
        if builtins.hasAttr "nerd-fonts" pkgs then
          (nerd-fonts.symbols-only)
        else
          (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
      )

      iosevkaLyteTerm
      spicetify-cli # CLI only, for use with Flatpak Spotify
    ];

    fonts.fontconfig.enable = true;

    home.file."${config.xdg.configHome}/.local/share/fonts" = {
      source = config.lib.file.mkOutOfStoreSymlink "/run/current-system/sw/share/X11/fonts";
    };

    home.file."${config.xdg.configHome}/ghostty" = {
      source = conditionalOutOfStoreSymlink config /etc/nix/flake/lib/modules/home/ghostty ./ghostty;
    };

    programs.firefox.enable = lib.mkDefault true;
    programs.ghostty.enable = lib.mkDefault true;
    home.pointerCursor = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 40;
    };
    gtk.cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 40;
    };
    # gtk.font = pkgs.iosevkaLyteTerm;
  };
}
