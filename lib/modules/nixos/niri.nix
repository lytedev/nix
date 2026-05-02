flakeInputs:
{
  options,
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.lyte.desktop.niri;
  dotfilesPath = config.lyte.dotfilesPath;
  shellBindings =
    if cfg.shell == "noctalia" then
      "${dotfilesPath}/niri/noctalia-bindings.kdl"
    else if cfg.shell == "dms" then
      "${dotfilesPath}/niri/dms-bindings.kdl"
    else
      pkgs.writeText "niri-shell-bindings-empty.kdl" "";

  lockCmd =
    if cfg.shell == "noctalia" then
      "noctalia-shell ipc call lockScreen lock"
    else if cfg.shell == "dms" then
      "dms ipc call lock lock"
    else
      "${pkgs.swaylock}/bin/swaylock -f";
in
{
  imports = [
    flakeInputs.noctalia.nixosModules.default
    flakeInputs.dankMaterialShell.nixosModules.default
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
    environment.systemPackages = with pkgs; [
      slurp
      grim
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

    # Pick a Quickshell-based desktop shell. Both upstream modules launch the
    # shell as a systemd user unit; spawn-at-startup is no longer needed.
    services.noctalia-shell = lib.mkIf (cfg.shell == "noctalia") {
      enable = true;
      package = flakeInputs.noctalia.packages.${pkgs.system}.default;
    };
    programs.dank-material-shell = lib.mkIf (cfg.shell == "dms") {
      enable = true;
      systemd.enable = true;
    };

    # Shell-specific keybindings + spawn-at-startup, included from config.kdl.
    environment.etc."niri/shell-bindings.kdl".source = shellBindings;
    programs.niri.enable = true;
    programs.dconf.enable = true;

    services.displayManager.defaultSession = lib.mkForce "niri";
    environment.etc."niri/laptop.kdl".text = lib.mkDefault "";

    # Enable display manager for login
    services.xserver.enable = true;

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
          default = lib.mkForce [
            "gtk"
            "kde"
          ];
          # kde.portal advertises ScreenCast/Screenshot but its impl requires
          # KWin to be running — under niri it never produces frames. Pin
          # these to xdg-desktop-portal-wlr (uses wlr-screencopy-unstable-v1,
          # which niri implements) so screen-share actually works.
          "org.freedesktop.impl.portal.ScreenCast" = "wlr";
          "org.freedesktop.impl.portal.Screenshot" = "wlr";
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
    # Polkit auth agent under niri (reuses the KDE agent already in the closure via Plasma)
    systemd.user.services.polkit-kde-agent = {
      description = "Polkit KDE authentication agent";
      wantedBy = [ "niri.service" ];
      after = [
        "niri.service"
        "xdg-desktop-autostart.target"
      ];
      partOf = [ "niri.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 3;
      };
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
        ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/touch ${config.lyte.userHome}/.config/niri/noctalia.kdl ${config.lyte.userHome}/.config/niri/host-specific.kdl'";
      };
    };

    # Swayidle for automatic locking and power management.
    # On laptops, also trigger suspend on idle — niri does not feed idle
    # hint to logind, so logind's IdleAction won't fire on its own.
    # HibernateDelaySec (set in laptop.nix) carries suspend -> hibernate.
    systemd.user.services.swayidle = {
      description = "Idle management daemon";
      wantedBy = [ "niri.service" ];
      after = [ "niri.service" ];
      partOf = [ "niri.service" ];
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " (
          [
            "${pkgs.swayidle}/bin/swayidle -w"
            "before-sleep '${pkgs.bash}/bin/bash -c \"${lockCmd}\"'"
            "lock '${pkgs.bash}/bin/bash -c \"${lockCmd}\"'"
            "timeout 600 '${pkgs.bash}/bin/bash -c \"${lockCmd}\"'"
          ]
          ++ lib.optional config.lyte.laptop.enable "timeout 660 '${pkgs.systemd}/bin/systemctl suspend'"
          ++ [
            "timeout 900 '${pkgs.niri}/bin/niri msg action power-off-monitors'"
          ]
        );
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
