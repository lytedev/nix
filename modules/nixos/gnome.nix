{
  pkgs,
  lib,
  ...
}: {
  imports = [./pipewire.nix];

  services.xserver.enable = true;
  services.xserver.displayManager.gdm = {
    enable = lib.mkDefault false;
  };

  services.xserver.desktopManager.gnome = {
    enable = true;
  };

  programs.gnupg.agent = {
    enable = true;
    pinentryFlavor = "gnome3";
    enableSSHSupport = true;
  };

  xdg.portal = {
    enable = true;
  };

  services.dbus.enable = true;

  services.gvfs = {
    enable = true;
  };

  services.udev.packages = with pkgs; [gnome.gnome-settings-daemon];

  environment = {
    variables = {
      GTK_THEME = "Catppuccin-Mocha-Compact-Sapphire-Dark";
      VISUAL = "hx";
      PAGER = "less";
      MANPAGER = "less";
    };

    systemPackages = with pkgs; [
      gnomeExtensions.appindicator
      libinput
      libinput-gestures
      libnotify
      noto-fonts
      pavucontrol
      wl-clipboard
      zathura
    ];
  };
}
