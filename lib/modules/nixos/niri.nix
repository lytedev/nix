flakeInputs:
{
  # options,
  pkgs,
  lib,
  config,
  ...
}:

{
  # options = {
  #   lyte = {
  #     desktop = {
  #       niri = {
  #       };
  #     };
  #   };
  # };

  imports = [
    # KDE Connect?
    flakeInputs.niri.nixosModules.niri
    # do some things even if we don't actually have the configuration setup
  ];

  config = lib.mkIf (config.lyte.desktop.enable && (config.lyte.desktop.niri.enable)) {
    nixpkgs.overlays = [ flakeInputs.niri.overlays.niri ];
    environment.systemPackages = with pkgs; [
      flakeInputs.noctalia.packages.${system}.default
    ];
    programs.niri.enable = true;
    programs.niri.package = pkgs.niri-unstable;
    programs.dconf.enable = true;

    qt = {
      enable = true;
      platformTheme = "gnome";
      style = "adwaita-dark";
    };

    # TODO: mako styles
    # TODO: media player keybinds

    # workaround for bug
    # from https://github.com/sodiboo/niri-flake/issues/1334
    # workaround source: https://github.com/sodiboo/niri-flake/issues/1366
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      wlr.enable = true;
      config = {
        common = {
          default = lib.mkForce [
            "gtk"
            "gnome"
          ];
        };
        niri = {
          default = [
            "gtk"
            "gnome"
          ];
        };
      };
    };
    xdg.portal.extraPortals = [
      pkgs.xdg-desktop-portal-wlr
      pkgs.xdg-desktop-portal-gtk
    ];
    systemd.user.services.xdg-desktop-portal = {
      after = [ "xdg-desktop-autostart.target" ];
    };
    systemd.user.services.xdg-desktop-portal-gtk = {
      after = [ "xdg-desktop-autostart.target" ];
    };
    systemd.user.services.xdg-desktop-portal-gnome = {
      after = [ "xdg-desktop-autostart.target" ];
    };
    systemd.user.services.niri-flake-polkit = {
      after = [ "xdg-desktop-autostart.target" ];
    };
  };
}
