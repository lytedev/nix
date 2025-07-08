{
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
          tray-icons.enable = lib.mkEnableOption {
            default = true;
          };
          gsconnect.enable = lib.mkEnableOption {
            default = true;
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

  config = lib.mkIf (config.lyte.desktop.enable && (config.lyte.desktop.environment == "gnome")) {
    services = {
      xserver = {
        enable = true;
        displayManager.gdm.enable = true;
        desktopManager.gnome.enable = true;
      };
    };

    environment = {
      systemPackages = with pkgs; [
        adwaita-fonts
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
