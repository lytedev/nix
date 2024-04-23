{
  pkgs,
  lib,
  ...
}: {
  imports = [./pipewire.nix];

  # NOTE: Plasma and Kitty seem to have some weird interactions where
  # occasionally, kitty's window will try to move or resize and crash the
  # compositor. Plasma recovers, but the Kitty window is quite dead and gone.
  # This has lost me a few minutes' work when I have not saved a file while
  # typing and I go to resize kitty and crash loses my work.
  # It is entirely possible that this is due to my configuration, though, and
  # not the fault of the applications themselves!
  # https://www.reddit.com/r/kde/comments/ohiwqf/kitty_crashes_plasma_wayland_session/
  # https://gitlab.archlinux.org/archlinux/packaging/packages/kitty/-/issues/3

  # NOTE: I'm switching to wezterm. Will this solve my issue?

  # qt.platformTheme = "gnome";

  services.desktopManager.plasma6.enable = true;

  services.xserver.displayManager.sddm.enable = true;
  services.xserver.displayManager.sddm.wayland.enable = true;

  services.xserver.displayManager.defaultSession = "plasma";
  services.xserver.enable = lib.mkDefault true;

  hardware.pulseaudio.enable = false;

  qt = {
    enable = true;
    #   platformTheme = "gnome";
    #   style = "adwaita-dark";
  };

  programs.gnupg.agent.pinentryPackage = lib.mkForce pkgs.pinentry-qt;

  programs.dconf.enable = true;

  services.dbus.enable = true;

  environment = {
    variables = {
      GTK_THEME = "Catppuccin-Mocha-Compact-Sapphire-Dark";
      VISUAL = "hx";
      PAGER = "less";
      MANPAGER = "less";
      GTK_USE_PORTAL = "1";
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
