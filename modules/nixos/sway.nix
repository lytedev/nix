{pkgs, ...}: {
  imports = [./pipewire.nix];

  # services.xserver.libinput.enable = true;

  services.gnome.gnome-keyring.enable = true;
  programs.gnupg.agent = {
    enable = true;
    pinentryFlavor = "gnome3";
    enableSSHSupport = true;
  };

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;

    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
    ];
  };

  services.dbus.enable = true;

  programs.thunar = {
    enable = true;
    plugins = with pkgs.xfce; [thunar-archive-plugin thunar-volman];
  };

  services.gvfs = {
    enable = true;
  };

  environment = {
    variables = {
      GTK_THEME = "hx";
      VISUAL = "hx";
      PAGER = "less";
      MANPAGER = "less";
    };

    systemPackages = with pkgs; [
      brightnessctl
      feh
      gimp
      grim
      inkscape
      krita
      libinput
      libinput-gestures
      libnotify
      lutris
      nil
      nixpkgs-fmt
      noto-fonts
      pamixer
      pavucontrol
      pgcli
      playerctl
      pulseaudio
      pulsemixer
      rclone
      restic
      slurp
      steam
      swaybg
      swayidle
      swaylock
      vlc
      vulkan-tools
      waybar
      weechat
      wine
      wl-clipboard
      wofi
      zathura
    ];
  };
}
