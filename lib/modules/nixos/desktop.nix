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
  dotfilesPath = config.lyte.dotfilesPath;
  danielHome = config.users.users.daniel.home;
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
          description = "Enable niri configuration and applications";
          type = types.bool;
          example = true;
        };
        gdm.backgroundImage = lib.mkOption {
          default = null;
          example = "/path/to/background.jpg";
          description = "Path to GDM background image. Set to null to use default.";
          type = types.nullOr types.path;
        };
        firefox = {
          enable = lib.mkOption {
            type = types.bool;
            default = cfg.enable;
            description = "Enable Firefox with profile setup";
          };
          mobile = lib.mkEnableOption "Use mobile Firefox profile instead of desktop";
        };
        easyeffects = {
          enable = lib.mkEnableOption "Enable EasyEffects audio processing";
          preset = lib.mkOption {
            type = types.str;
            default = "";
            description = "EasyEffects preset to load";
          };
          presetsSource = lib.mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to EasyEffects presets directory (e.g. from fetchGit)";
          };
        };
      };
    };
  };

  config = lib.mkMerge [
    # Apply GDM background image if configured
    (lib.mkIf (cfg.enable && cfg.gdm.backgroundImage != null) {
      nixpkgs.overlays = [
        (self: super: {
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
                    +  background-image: url('file://${cfg.gdm.backgroundImage}');
                    +  background-size: cover;
                     }
                  '')
                ];
              });
            }
          );
        })
      ];
    })

    (lib.mkIf cfg.enable {
      services.orca.enable = false;

      # Configure GDM to use daniel's monitor configuration
      systemd.tmpfiles.rules = [
        "L+ /var/lib/gdm/.config/monitors.xml - - - - ${danielHome}/.config/monitors.xml"
      ];

      services.pipewire.enable = true;
      environment.systemPackages = with pkgs; [
        pavucontrol
        pulsemixer
        libnotify
        wl-clipboard
        xdg-terminal-exec
        squashfsTools
        fractal
        (symlinkJoin {
          name = "element-desktop-wrapped";
          paths = [ element-desktop ];
          buildInputs = [ makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/element-desktop \
              --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libsecret ]}"
          '';
        })

        # Desktop fonts and tools
        (
          if builtins.hasAttr "nerd-fonts" pkgs then
            (nerd-fonts.symbols-only)
          else
            (nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
        )
        iosevkaLyteTerm
        gradia
        spicetify-cli
        bibata-cursors

        # Ghostty
        ghostty
      ];

      fonts.packages = [
        (
          if builtins.hasAttr "nerd-fonts" pkgs then
            (pkgs.nerd-fonts.symbols-only)
          else
            (pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
        )
        pkgs.iosevkaLyteTerm
      ];

      fonts.fontDir.enable = true;

      xdg.portal.enable = true;
      xdg.mime.defaultApplications = {
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "text/html" = "firefox.desktop";
        "application/xhtml+xml" = "firefox.desktop";
      };

      hardware =
        if builtins.hasAttr "graphics" options.hardware then
          {
            graphics.enable = true;
          }
        else
          {
            opengl = {
              enable = true;
              driSupport = true;
            };
          };

      services.flatpak.enable = true;
      services.udev.extraRules = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="0d28", ATTR{idProduct}=="0204", MODE="0664", GROUP="dialout"
      '';
      programs.appimage = {
        enable = true;
        binfmt = true;
      };
      services.printing.enable = true;
      programs.virt-manager.enable = config.virtualisation.libvirtd.enable;

      # Cursor and GTK theme
      environment.sessionVariables = {
        XCURSOR_THEME = "Bibata-Modern-Classic";
        XCURSOR_SIZE = "40";
        MOZ_ENABLE_WAYLAND = "1";
      };

      # Symlinks for desktop configs
      lyte.userSymlinks = {
        ".config/ghostty" = "${dotfilesPath}/ghostty";
        ".local/share/fonts" = "/run/current-system/sw/share/X11/fonts";
      };

      # Cursor theme index and GTK settings
      lyte.userFiles = {
        ".icons/default/index.theme" = ''
          [Icon Theme]
          Name=Default
          Comment=Default Cursor Theme
          Inherits=Bibata-Modern-Classic
        '';
        ".config/gtk-3.0/settings.ini" = ''
          [Settings]
          gtk-cursor-theme-name=Bibata-Modern-Classic
          gtk-cursor-theme-size=40
        '';
        ".config/gtk-4.0/settings.ini" = ''
          [Settings]
          gtk-cursor-theme-name=Bibata-Modern-Classic
          gtk-cursor-theme-size=40
        '';
      };
    })

    # Firefox profile setup
    (lib.mkIf (cfg.enable && cfg.firefox.enable) {
      environment.systemPackages = with pkgs; [
        firefox
        pywal
        pywalfox-native
      ];

      lyte.userFiles.".mozilla/firefox/profiles.ini" = ''
        [General]
        StartWithLastProfile=1

        [Profile0]
        Name=primary
        IsRelative=1
        Path=primary
        Default=1
      '';

      lyte.userSymlinks = lib.mkIf (!cfg.firefox.mobile) {
        ".mozilla/firefox/primary/user.js" = "${dotfilesPath}/firefox/user.js";
        ".mozilla/firefox/primary/chrome/userChrome.css" = "${dotfilesPath}/firefox/userChrome.css";
      };
    })

    # Mobile Firefox profile override
    (lib.mkIf (cfg.enable && cfg.firefox.enable && cfg.firefox.mobile) {
      lyte.userSymlinks = {
        ".mozilla/firefox/primary/user.js" = "${dotfilesPath}/firefox-mobile/user.js";
        ".mozilla/firefox/primary/chrome/userChrome.css" = "${dotfilesPath}/firefox-mobile/userchrome.css";
        ".mozilla/firefox/primary/chrome/userContent.css" =
          "${dotfilesPath}/firefox-mobile/usercontent.css";
      };
    })

    # EasyEffects
    (lib.mkIf cfg.easyeffects.enable {
      environment.systemPackages = [ pkgs.easyeffects ];

      systemd.user.services.easyeffects = {
        description = "EasyEffects audio processing";
        wantedBy = [ "graphical-session.target" ];
        after = [ "pipewire.service" ];
        partOf = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart =
            "${pkgs.easyeffects}/bin/easyeffects --gapplication-service"
            + lib.optionalString (cfg.easyeffects.preset != "") " -l ${cfg.easyeffects.preset}";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      lyte.userSymlinks = lib.mkIf (cfg.easyeffects.presetsSource != null) {
        ".config/easyeffects/output" = toString cfg.easyeffects.presetsSource;
      };
    })
  ];
}
