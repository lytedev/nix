{pkgs, ...}: {
  imports = [
    ./pipewire.nix
  ];

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # services.xserver.libinput.enable = true;

  services.gnome.gnome-keyring.enable = true;

  xdg.portal = {
    enable = true;
    wlr.enable = true;

    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
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
      GTK_THEME = "Catppuccin-Mocha-Compact-Sapphire-Dark";
      VISUAL = "hx";
      PAGER = "less";
      MANPAGER = "less";
    };

    systemPackages = with pkgs; [
      brightnessctl
      feh
      # gimp
      grim
      # inkscape
      # krita
      libinput
      libinput-gestures
      libnotify
      # mako
      # lutris
      # nil
      # nixpkgs-fmt
      noto-fonts
      pamixer
      # pavucontrol
      playerctl
      pulseaudio
      pulsemixer
      # rclone
      # restic
      slurp
      # steam
      swaybg
      swayidle
      swaylock
      swayosd
      tofi
      # vlc
      # vulkan-tools
      waybar
      # weechat
      # wine
      wl-clipboard
      zathura
    ];
  };
}
