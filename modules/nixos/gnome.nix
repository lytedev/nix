{pkgs, ...}: {
  imports = [./pipewire.nix];

  services.xserver.enable = true;
  services.xserver.displayManager.gdm = {
    enable = true;
  };

  hardware.pulseaudio.enable = false;

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
      # pulseaudio
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
