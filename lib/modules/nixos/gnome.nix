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

    environment = {
      systemPackages = with pkgs; [
        adwaita-fonts
        file-roller
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
  };
}
