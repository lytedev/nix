{pkgs, ...}: {
  imports = [
    ./pipewire.nix
  ];

  # services.xserver.libinput.enable = true;

  services.gnome.gnome-keyring.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # settings = {
    #   pinentry-program = "/run/current-system/sw/bin/pinentry";
    # };
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
