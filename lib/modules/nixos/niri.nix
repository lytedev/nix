flakeInputs:
{
  options,
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    flakeInputs.niri.nixosModules.niri
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
      vicinae

      # Niri user packages (absorbed from HM)
      swayosd
      swaylock
      swayidle
      fuzzel
      brightnessctl
      xwayland-satellite
      vesktop
    ];
    programs.niri.enable = true;
    programs.niri.package = pkgs.niri-unstable;
    programs.dconf.enable = true;
    environment.etc."niri/laptop.kdl".text = lib.mkDefault "";

    # Enable plasma-login-manager for login
    services.xserver.enable = true;
    services.displayManager.plasma-login-manager.enable = true;

    qt = {
      enable = true;
      platformTheme = "kde";
      style = "breeze";
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
            "kde"
          ];
        };
        niri = {
          default = [
            "gtk"
            "kde"
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
    systemd.user.services.niri-flake-polkit = {
      after = [ "xdg-desktop-autostart.target" ];
    };

    systemd.user.extraConfig = ''
      DefaultEnvironment="PATH=/run/current-system/sw/bin:/etc/profiles/per-user/%u/bin"
    '';

    # Niri user services (absorbed from HM)

    # Ensure niri config include files exist before starting niri
    systemd.user.services.niri-file-setup = {
      description = "Ensure niri config include files exist";
      wantedBy = [ "niri.service" ];
      before = [ "niri.service" ];
      partOf = [ "niri.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/touch ${config.users.users.daniel.home}/.config/niri/noctalia.kdl ${config.users.users.daniel.home}/.config/niri/host-specific.kdl'";
      };
    };

    # Noctalia shell service
    systemd.user.services.noctalia-shell = {
      description = "Noctalia Shell for niri";
      wantedBy = [ "niri.service" ];
      after = [ "niri.service" ];
      partOf = [ "niri.service" ];
      serviceConfig = {
        ExecStart = "${flakeInputs.noctalia.packages.${pkgs.system}.default}/bin/noctalia-shell";
        Restart = "on-failure";
        RestartSec = 3;
      };
    };

    # Swayidle for automatic locking and power management
    systemd.user.services.swayidle = {
      description = "Idle management daemon";
      wantedBy = [ "niri.service" ];
      after = [ "niri.service" ];
      partOf = [ "niri.service" ];
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.swayidle}/bin/swayidle -w"
          "before-sleep '${pkgs.bash}/bin/bash -c \"noctalia-shell ipc call lockScreen lock\"'"
          "lock '${pkgs.bash}/bin/bash -c \"noctalia-shell ipc call lockScreen lock\"'"
          "timeout 600 '${pkgs.bash}/bin/bash -c \"noctalia-shell ipc call lockScreen lock\"'"
          "timeout 900 '${pkgs.niri-unstable}/bin/niri msg action power-off-monitors'"
        ];
        Restart = "on-failure";
        RestartSec = 3;
      };
    };

    # Niri dconf and GTK settings
    lyte.dconfSettings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
    lyte.userFiles = {
      ".config/gtk-3.0/settings.ini" = lib.mkForce ''
        [Settings]
        gtk-cursor-theme-name=Bibata-Modern-Classic
        gtk-cursor-theme-size=40
        gtk-theme-name=Adwaita
      '';
      ".config/gtk-4.0/settings.ini" = lib.mkForce ''
        [Settings]
        gtk-cursor-theme-name=Bibata-Modern-Classic
        gtk-cursor-theme-size=40
        gtk-theme-name=Adwaita
      '';
    };

    # Symlinks for niri and ironbar config
    lyte.userSymlinks = {
      ".config/niri" = "${config.lyte.dotfilesPath}/niri";
      ".config/ironbar" = "${config.lyte.dotfilesPath}/ironbar";
    };
  };
}
