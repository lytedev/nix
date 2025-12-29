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
        gnome.enable = lib.mkOption {
          default = config.lyte.desktop.enable;
          example = true;
          description = "Enable GNOME desktop configuration and applications";
          type = types.bool;
        };
        cosmic.enable = lib.mkEnableOption "Enable Cosmic desktop configuration and applications";
        plasma.enable = lib.mkEnableOption "Enable Plasma configuration and applications";
        niri.enable = lib.mkOption {
          default = config.lyte.desktop.enable;
          description = "Enable Plasma configuration and applications";
          type = types.bool;
          example = true;
        };
        gdm.backgroundImage = lib.mkOption {
          default = null;
          example = "/path/to/background.jpg";
          description = "Path to GDM background image. Set to null to use default.";
          type = types.nullOr types.path;
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Apply GDM background image if configured
    nixpkgs.overlays = lib.optional (config.lyte.desktop.gdm.backgroundImage != null) (
      self: super: {
        squashfsTools = super.squashfsTools.override { zstdSupport = true; };
        gnome = super.gnome.overrideScope (
          selfg: superg: {
            gnome-shell = superg.gnome-shell.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [
                (pkgs.writeText "gdm-bg.patch" ''
                  --- a/data/theme/gnome-shell-sass/widgets/_login-lock.scss
                  +++ b/data/theme/gnome-shell-sass/widgets/_login-lock.scss
                  @@ -15,4 +15,5 @@ $_gdm_dialog_width: 23em;
                   /* Login Dialog */
                   .login-dialog {
                     background-color: $_gdm_bg;
                  +  background-image: url('file://${config.lyte.desktop.gdm.backgroundImage}');
                  +  background-size: cover;
                   }
                '')
              ];
            });
          }
        );
      }
    );

    services.orca.enable = false;

    # Configure GDM to use daniel's monitor configuration
    # This will show the login screen on the correct monitor(s)
    systemd.tmpfiles.rules = [
      "L+ /var/lib/gdm/.config/monitors.xml - - - - ${config.users.users.daniel.home}/.config/monitors.xml"
    ];

    services.pipewire.enable = true;
    environment.systemPackages = with pkgs; [
      wl-clipboard # wayland clipboard CLI tools

      # for enabling glib-based tools to be able to launch the default terminal properly
      # translation: this lets `xdg-open /my-file.txt` properly open the text file in helix in ghostty and not xterm
      # see https://gitlab.gnome.org/GNOME/glib/-/blob/5da569a4253ab4b9a7ff9fcf8595c33f3c324a45/gio/gdesktopappinfo.c#L2720
      xdg-terminal-exec

      # for appimage support
      squashfsTools
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
    programs.appimage = {
      enable = true;
      binfmt = true;
    };
    services.printing.enable = true;
    programs.virt-manager.enable = config.virtualisation.libvirtd.enable;
  };
}
