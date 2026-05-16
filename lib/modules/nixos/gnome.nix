{
  options,
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    lyte = {
      desktop = {
        gnome = {
          tray-icons.enable = lib.mkOption {
            type = lib.types.bool;
            default = config.lyte.desktop.gnome.enable;
            description = "Enable tray icons support";
          };
          gsconnect.enable = lib.mkOption {
            type = lib.types.bool;
            default = config.lyte.desktop.gnome.enable;
            description = "Enable GSConnect for phone integration";
          };
        };
      };
    };
  };

  imports = [
    {
      config = lib.mkIf config.lyte.desktop.gnome.tray-icons.enable {
        environment.systemPackages = [ pkgs.gnomeExtensions.appindicator ];
        services.udev.packages = [ pkgs.gnome-settings-daemon ];
      };
    }
    {
      config = lib.mkIf config.lyte.desktop.gnome.gsconnect.enable {
        programs.kdeconnect = {
          enable = true;
          package = pkgs.gnomeExtensions.gsconnect;
        };

        networking.firewall = rec {
          allowedTCPPortRanges = [
            {
              from = 1714;
              to = 1764;
            }
          ];
          allowedUDPPortRanges = allowedTCPPortRanges;
        };
      };
    }
  ];

  config = lib.mkIf (config.lyte.desktop.enable && config.lyte.desktop.gnome.enable) {
    xdg.portal.enable = true;
    xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    xdg.portal.config = {
      common = {
        default = [
          "gtk"
        ];
      };
    };
    services =
      (
        if
          (builtins.hasAttr "displayManager" options.services)
          && (builtins.hasAttr "gdm" options.services.displayManager)
        then
          {
            displayManager.gdm = {
              enable = true;
              wayland = true;
            };
            desktopManager.gnome.enable = true;
          }
        else
          {
            xserver = {
              displayManager.gdm = {
                enable = true;
                wayland = true;
              };
              desktopManager.gnome.enable = true;
            };
          }
      )
      // {
        gnome.gnome-keyring.enable = true;

        xserver = {
          enable = true;
        };
      };

    programs.dconf.enable = true;

    environment = {
      systemPackages = with pkgs; [
        adwaita-fonts
        file-roller
        # GNOME Shell extensions
        gnomeExtensions.tiling-shell
        gnomeExtensions.blur-my-shell
        gnomeExtensions.appindicator
        gnomeExtensions.gsconnect
      ];
      gnome.excludePackages = with pkgs; [
        baobab
        decibels
        epiphany
        gnome-text-editor
        gnome-calculator
        gnome-calendar
        gnome-characters
        gnome-clocks
        gnome-console
        gnome-contacts
        gnome-font-viewer
        gnome-logs
        gnome-maps
        gnome-music
        gnome-system-monitor
        gnome-weather
        loupe
        gnome-connections
        simple-scan
        snapshot
        totem
        yelp
      ];
    };

    # GNOME dconf settings (applied per-user via activation script)
    lyte.dconfSettings = {
      "org/gnome/desktop/input-sources" = {
        xkb-options = [ "caps:ctrl_modifier" ];
      };
      "org/gnome/settings-daemon/plugins/media-keys" = {
        screensaver = [ "<Shift><Control><Super>l" ];
        mic-mute = [ "<Shift><Super>v" ];
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        ];
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        name = "Clipshot Screenshot";
        binding = "<Shift><Super>s";
        command = "clipshot";
      };
      "org/gnome/desktop/default-applications/terminal" = {
        exec = "ghostty";
      };
      "org/gnome/desktop/peripherals/keyboard" = {
        repeat = true;
        repeat-interval = {
          _type = "uint32";
          value = 10;
        };
        delay = {
          _type = "uint32";
          value = 200;
        };
      };
      "org/gnome/desktop/wm/preferences" = {
        resize-with-right-button = true;
      };
      "org/gnome/desktop/wm/keybindings" = {
        minimize = [ "<Shift><Control><Super>h" ];
        show-desktop = [ "<Super>d" ];
        move-to-workspace-left = [ "<Super><Shift>h" ];
        move-to-workspace-right = [ "<Super><Shift>l" ];
        switch-to-workspace-left = [ "<Super><Control>h" ];
        switch-to-workspace-right = [ "<Super><Control>l" ];
      };
      "org/gnome/desktop/interface" = {
        show-battery-percentage = true;
        clock-show-weekday = true;
      };
      "org/gnome/mutter" = {
        experimental-features = [
          "variable-refresh-rate"
          "scale-monitor-framebuffer"
        ];
      };
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = with pkgs.gnomeExtensions; [
          tiling-shell.extensionUuid
          appindicator.extensionUuid
          blur-my-shell.extensionUuid
        ];
      };
      "org/gnome/shell/extensions/tilingshell" = {
        inner-gaps = {
          _type = "uint32";
          value = 8;
        };
        outer-gaps = {
          _type = "uint32";
          value = 8;
        };
        window-border-width = {
          _type = "uint32";
          value = 2;
        };
        window-border-color = "rgba(116,199,236,0.47)";
        focus-window-right = [ "<Super>l" ];
        focus-window-left = [ "<Super>h" ];
        focus-window-up = [ "<Super>k" ];
        focus-window-down = [ "<Super>j" ];
      };
    };

    # MIME type associations (system-wide via NixOS xdg.mime)
    xdg.mime.defaultApplications = {
      "application/zip" = "org.gnome.FileRoller.desktop";
      "application/x-tar" = "org.gnome.FileRoller.desktop";
      "application/gzip" = "org.gnome.FileRoller.desktop";
      "application/x-gzip" = "org.gnome.FileRoller.desktop";
      "application/x-bzip2" = "org.gnome.FileRoller.desktop";
      "application/x-xz" = "org.gnome.FileRoller.desktop";
      "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
      "application/x-rar" = "org.gnome.FileRoller.desktop";
      "application/x-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-bzip-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-xz-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-lzma-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-zstd-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/x-lz4-compressed-tar" = "org.gnome.FileRoller.desktop";
      "application/zstd" = "org.gnome.FileRoller.desktop";
      "application/x-lz4" = "org.gnome.FileRoller.desktop";
      "application/x-lzip" = "org.gnome.FileRoller.desktop";
      "application/vnd.debian.binary-package" = "org.gnome.FileRoller.desktop";
      "application/x-rpm" = "org.gnome.FileRoller.desktop";
      "application/java-archive" = "org.gnome.FileRoller.desktop";
      "application/x-cpio" = "org.gnome.FileRoller.desktop";
      "application/x-archive" = "org.gnome.FileRoller.desktop";
      "application/x-iso9660-image" = "org.gnome.FileRoller.desktop";
      "application/vnd.ms-cab-compressed" = "org.gnome.FileRoller.desktop";
      "application/x-xar" = "org.gnome.FileRoller.desktop";
      "application/x-lha" = "org.gnome.FileRoller.desktop";
    };
  };
}
