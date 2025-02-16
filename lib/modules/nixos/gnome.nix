{
  pkgs,
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.services.xserver.desktopManager.gnome.enable {

    services = {
      xserver = {
        enable = true;
        displayManager.gdm.enable = true;
        # desktopManager.gnome.enable = true;
      };
      udev.packages = [ pkgs.gnome-settings-daemon ];
    };

    environment = {
      variables.GSK_RENDERER = "gl";
      systemPackages = with pkgs; [
        bitwarden
        # adwaita-gtk-theme
        papirus-icon-theme
        adwaita-icon-theme
        adwaita-icon-theme-legacy
        hydrapaper
      ];
    };

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
