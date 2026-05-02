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

  oskToggle =
    if cfg.osk == "wvkbd" then
      pkgs.writeShellScriptBin "osk-toggle" ''
        set -eu
        # wvkbd-mobintl listens for SIGRTMIN+8 to toggle visibility when
        # started with --hidden. Make sure the service is up first.
        ${pkgs.systemd}/bin/systemctl --user -q is-active wvkbd.service \
          || ${pkgs.systemd}/bin/systemctl --user start wvkbd.service
        ${pkgs.procps}/bin/pkill -SIGRTMIN+8 wvkbd-mobintl
      ''
    else if cfg.osk == "squeekboard" then
      pkgs.writeShellScriptBin "osk-toggle" ''
        set -eu
        if ! ${pkgs.systemd}/bin/systemctl --user -q is-active squeekboard.service; then
          ${pkgs.systemd}/bin/systemctl --user start squeekboard.service
          exit 0
        fi
        visible=$(${pkgs.systemd}/bin/busctl --user get-property \
          sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 Visible 2>/dev/null \
          | ${pkgs.gawk}/bin/awk '{print $2}')
        if [ "$visible" = "true" ]; then
          ${pkgs.systemd}/bin/busctl --user call \
            sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b false
        else
          ${pkgs.systemd}/bin/busctl --user call \
            sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b true
        fi
      ''
    else
      pkgs.writeShellScriptBin "osk-toggle" "exit 0";
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
    environment.systemPackages =
      (with pkgs; [
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
      ])
      ++ lib.optional (cfg.osk != "none") oskToggle;

    # Pick a Quickshell-based desktop shell. Both upstream modules launch the
    # shell as a systemd user unit; spawn-at-startup is no longer needed.
    services.noctalia-shell = lib.mkIf (cfg.shell == "noctalia") {
      enable = true;
      package = flakeInputs.noctalia.packages.${pkgs.system}.default;
    };
    programs.dank-material-shell = lib.mkIf (cfg.shell == "dms") {
      enable = true;
      systemd.enable = true;
      plugins = lib.mkIf (cfg.osk != "none") {
        oskToggle = {
          enable = true;
          src = "${dotfilesPath}/dms-osk-plugin";
        };
      };
    };

    # Shell-specific keybindings + spawn-at-startup, included from config.kdl.
    environment.etc."niri/shell-bindings.kdl".source = shellBindings;

    # On-screen keyboard for touchscreen hosts.
    services.dbus.packages = lib.mkIf (cfg.osk == "squeekboard") [ pkgs.squeekboard ];

    systemd.user.services.squeekboard = lib.mkIf (cfg.osk == "squeekboard") {
      description = "Squeekboard on-screen keyboard";
      wantedBy = [ "niri.service" ];
      after = [ "niri.service" ];
      partOf = [ "niri.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.squeekboard}/bin/squeekboard";
        Restart = "on-failure";
        RestartSec = 3;
      };
    };

    systemd.user.services.wvkbd =
      let
        # wvkbd 0.19.4 (current nixpkgs) sends a keymap_size that doesn't
        # include the trailing NUL byte, then strcpy's one byte past the
        # mmap region → SIGBUS at startup. Upstream issue:
        # https://github.com/jjsullivan5196/wvkbd/issues/119
        wvkbdPatched = pkgs.wvkbd.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace keyboard.c \
              --replace-fail \
                'keymap_size = strlen(keymap_str);' \
                'keymap_size = strlen(keymap_str) + 1;'
          '';
        });
      in
      lib.mkIf (cfg.osk == "wvkbd") {
        description = "wvkbd on-screen keyboard (hidden, toggled via SIGRTMIN+8)";
        wantedBy = [ "niri.service" ];
        after = [ "niri.service" ];
        partOf = [ "niri.service" ];
        serviceConfig = {
          ExecStart = "${wvkbdPatched}/bin/wvkbd-mobintl --hidden";
          Restart = "on-failure";
          RestartSec = 3;
        };
      };
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

    # Quickshell does not clean up its $XDG_RUNTIME_DIR/quickshell/by-id/<id>
    # directories on abnormal exit. Crash-loops (e.g. broken QML imports)
    # can fill the 784M tmpfs with thousands of stale instance dirs, after
    # which posix_fallocate() in any Wayland client returns ENOSPC and
    # mmap-backed clients (wvkbd, squeekboard, etc.) SIGBUS on access.
    # Sweep dead entries before each niri session.
    systemd.user.services.quickshell-runtime-cleanup = {
      description = "Reap stale Quickshell instance dirs in XDG_RUNTIME_DIR";
      wantedBy = [ "niri.service" ];
      before = [ "niri.service" ];
      partOf = [ "niri.service" ];
      path = [
        pkgs.coreutils
        pkgs.psmisc
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "quickshell-runtime-cleanup" ''
          set -eu
          dir="$XDG_RUNTIME_DIR/quickshell/by-id"
          [ -d "$dir" ] || exit 0
          for d in "$dir"/*/; do
            [ -d "$d" ] || continue
            if [ -f "$d/instance.lock" ]; then
              if fuser "$d/instance.lock" >/dev/null 2>&1; then
                continue
              fi
            fi
            rm -rf "$d"
          done
        '';
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
