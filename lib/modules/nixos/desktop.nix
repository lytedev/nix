{
  pkgs,
  lib,
  config,
  options,
  ...
}:
let
  cfg = config.lyte.desktop;
  types = lib.types;
in
{
  options = {
    lyte = {
      desktop = {
        enable = lib.mkEnableOption "Enable my default desktop configuration and applications";
        environment = lib.mkOption {
          type = types.enum [
            "gnome"
            "plasma"
          ];
          default = "gnome";
        };
        extraEnvironments = lib.mkOption {
          default = [ ];
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    services.pipewire.enable = true;
    environment.systemPackages = with pkgs; [
      wl-clipboard # wayland clipboard CLI tools

      # for enabling glib-based tools to be able to launch the default terminal properly
      # translation: this lets `xdg-open /my-file.txt` properly open the text file in helix in ghostty and not xterm
      # see https://gitlab.gnome.org/GNOME/glib/-/blob/5da569a4253ab4b9a7ff9fcf8595c33f3c324a45/gio/gdesktopappinfo.c#L2720
      xdg-terminal-exec
    ];

    fonts.packages = [
      (
        # allow nixpkgs 24.11 and unstable to both work
        if builtins.hasAttr "nerd-fonts" pkgs then
          (pkgs.nerd-fonts.symbols-only)
        else
          (pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
      )
      pkgs.iosevkaLyteTerm
    ];

    # enable flatpak to find system fonts
    # https://nixos.wiki/wiki/Fonts#Flatpak_applications_can.27t_find_system_fonts
    fonts.fontDir.enable = true;

    xdg.portal.enable = true;

    hardware =
      if builtins.hasAttr "graphics" options.hardware then
        {
          graphics = {
            enable = true;
            # enable32Bit = true;
            /*
              driSupport32Bit = true;
              driSupport = true;
            */
          };
        }
      else
        {
          opengl = {
            enable = true;
            # driSupport32Bit = true;
            driSupport = true;
          };
        };

    services.flatpak.enable = true;
    programs.appimage.binfmt = true;
    services.printing.enable = true;
    programs.virt-manager.enable = config.virtualisation.libvirtd.enable;
  };
}
