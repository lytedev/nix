{ pkgs, ... }:
let
  # this is unused because it's referenced by my sway config
  dbus-sway-environment = pkgs.writeTextFile {
    name = "dbus-sway-environment";
    destination = "/bin/dbus-sway-environment";
    executable = true;

    text = ''
      			dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway
      			systemctl --user stop wireplumber xdg-desktop-portal xdg-desktop-portal-wlr
      			systemctl --user start wireplumber xdg-desktop-portal xdg-desktop-portal-wlr
      		'';
  };

  # this is unused because it's referenced by my sway config
  configure-gtk = pkgs.writeTextFile {
    name = "configure-gtk";
    destination = "/bin/configure-gtk";
    executable = true;
    text =
      let
        schema = pkgs.gsettings-desktop-schemas;
        datadir = "${schema}/share/gsettings-schemas/${schema.name}";
      in
      ''
        				export XDG_DATA_DIRS="${datadir}:$XDG_DATA_DIRS
        				gnome_schema = org.gnome.desktop.interface
        				gsettings set $gnome_schema gtk-theme 'Catppuccin-Mocha'
        			'';
  };
in
{
  imports = [ ./pipewire.nix ];

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
    plugins = with pkgs.xfce; [ thunar-archive-plugin thunar-volman ];
  };

  environment.systemPackages = with pkgs; [
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
    mako
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
}
