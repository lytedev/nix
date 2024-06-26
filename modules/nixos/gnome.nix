{
  pkgs,
  lib,
  ...
}: {
  imports = [./pipewire.nix];

  # mkForce is used liberally to take precedence over KDE Plasma
  # so I can have both "usable" at once

  services.xserver.enable = lib.mkDefault true;
  services.xserver.displayManager.gdm = {
    enable = lib.mkForce true; # take precedence over KDE's SDDM
  };
  services.displayManager.execCmd = lib.mkForce "exec ${pkgs.gnome.gdm}/bin/gdm";
  services.displayManager.defaultSession = lib.mkForce "gnome";
  programs.ssh.askPassword = "${pkgs.gnome.seahorse}/libexec/seahorse/ssh-askpass";

  hardware.pulseaudio.enable = false;

  services.xserver.desktopManager.gnome = {
    enable = lib.mkDefault true;

    extraGSettingsOverridePackages = [pkgs.gnome.mutter];
    extraGSettingsOverrides = ''
      [org.gnome.mutter]
      experimental-features=['scale-monitor-framebuffer']
    '';
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
      gnome.gnome-power-manager
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
