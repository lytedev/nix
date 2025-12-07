flakeInputs:
{
  options,
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
    flakeInputs.niri.nixosModules.niri
    # do some things even if we don't actually have the configuration setup
  ];

  config = lib.mkIf (config.lyte.desktop.enable && (config.lyte.desktop.niri.enable)) {
    # Enable KDE Connect with firewall rules
    programs.kdeconnect.enable = true;
    networking.firewall = rec {
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      allowedUDPPortRanges = allowedTCPPortRanges;
    };
    nixpkgs.overlays = [ flakeInputs.niri.overlays.niri ];
    environment.systemPackages = with pkgs; [
      flakeInputs.noctalia.packages.${system}.default
      slurp
      grim
      quickshell
      kdePackages.kdeconnect-kde
    ];
    programs.niri.enable = true;
    programs.niri.package = pkgs.niri-unstable;
    programs.dconf.enable = true;

    # Enable GDM for login
    services = {
      xserver.enable = true;
    }
    // (
      if
        (builtins.hasAttr "displayManager" options.services)
        && (builtins.hasAttr "gdm" options.services.displayManager)
      then
        {
          displayManager.gdm = {
            enable = true;
            wayland = true;
          };
        }
      else
        {
          xserver.displayManager.gdm = {
            enable = true;
            wayland = true;
          };
        }
    );

    qt = {
      enable = true;
      platformTheme = "gnome";
      style = "adwaita-dark";
    };

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
      serviceConfig.Environment = lib.mkForce "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/daniel/bin";
    };
    systemd.user.services.xdg-desktop-portal-gtk = {
      after = [ "xdg-desktop-autostart.target" ];
      serviceConfig.Environment = lib.mkForce "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/daniel/bin";
    };
    systemd.user.services.xdg-desktop-portal-gnome = {
      after = [ "xdg-desktop-autostart.target" ];
      serviceConfig.Environment = lib.mkForce "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/daniel/bin";
    };
    systemd.user.services.niri-flake-polkit = {
      after = [ "xdg-desktop-autostart.target" ];
    };

    # Lock screen now configured with swaylock fallback (see lib/modules/home/default.nix and lib/modules/home/niri/config.kdl)
    # TODO: noctalia doesn't seem to be generating ghostty themes on flab?
    # TODO: resume issues on flab when in noctalia? - may be related to swayidle or systemd-logind config

    # Fix xdg-desktop-portal not having access to firefox and other binaries
    # See: https://github.com/NixOS/nixpkgs/issues/189851
    systemd.user.extraConfig = ''
      DefaultEnvironment="PATH=/run/current-system/sw/bin:/etc/profiles/per-user/%u/bin"
    '';
  };
}
