{
  pkgs,
  lib,
  ...
}: {
  imports = [./pipewire.nix];

  # qt.platformTheme = "gnome";

  services.xserver.displayManager.defaultSession = "plasma";
  services.xserver.enable = lib.mkDefault true;

  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma6.enable = true;

  hardware.pulseaudio.enable = false;

  qt = {
    enable = true;
    #   platformTheme = "gnome";
    #   style = "adwaita-dark";
  };

  programs.dconf.enable = true;

  services.dbus.enable = true;

  environment = {
    variables = {
      GTK_THEME = "Catppuccin-Mocha-Compact-Sapphire-Dark";
      VISUAL = "hx";
      PAGER = "less";
      MANPAGER = "less";
    };

    systemPackages = with pkgs; [
      inkscape
      krita
      noto-fonts
      vlc
      wl-clipboard
      libsForQt5.kate
      libsForQt5.kdenlive
      libsForQt5.merkuro
      libsForQt5.kcalc
      libsForQt5.neochat
      libsForQt5.filelight
      libsForQt5.krdc
      libsForQt5.krfb
      libsForQt5.kclock
      libsForQt5.kweather
      libsForQt5.ktorrent
      libsForQt5.kdevelop
      libsForQt5.kdialog
      libsForQt5.kdeplasma-addons
    ];
  };
}
