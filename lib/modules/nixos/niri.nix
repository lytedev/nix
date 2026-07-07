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

  # ayu-dark GTK theme: re-map Adwaita/libadwaita's named colors to the ayu palette
  # (same values as the greeter's regreet CSS). Loaded via ~/.config/gtk-3.0/gtk.css +
  # gtk-4.0/gtk.css so GTK3 and GTK4/libadwaita apps pick it up. It overrides the
  # colors directly, so it themes apps regardless of the (finicky here) gsettings
  # color-scheme path.
  ayuGtkCss = ''
    @define-color window_bg_color #0b0e14;
    @define-color window_fg_color #bfbdb6;
    @define-color view_bg_color #0f1419;
    @define-color view_fg_color #bfbdb6;
    @define-color card_bg_color #0f1419;
    @define-color card_fg_color #bfbdb6;
    @define-color popover_bg_color #0f1419;
    @define-color popover_fg_color #bfbdb6;
    @define-color dialog_bg_color #0b0e14;
    @define-color dialog_fg_color #bfbdb6;
    @define-color headerbar_bg_color #0f1419;
    @define-color headerbar_fg_color #bfbdb6;
    @define-color headerbar_backdrop_color #0b0e14;
    @define-color sidebar_bg_color #0b0e14;
    @define-color sidebar_fg_color #bfbdb6;
    @define-color accent_bg_color #e6b450;
    @define-color accent_fg_color #0b0e14;
    @define-color accent_color #ffb454;
    @define-color theme_bg_color #0b0e14;
    @define-color theme_fg_color #bfbdb6;
    @define-color theme_base_color #0f1419;
    @define-color theme_text_color #bfbdb6;
    @define-color theme_selected_bg_color #e6b450;
    @define-color theme_selected_fg_color #0b0e14;
    @define-color borders #1e232b;

    window, .background { background-color: #0b0e14; color: #bfbdb6; }
  '';

  # Absolute paths: these run from niri's spawn env and the swayidle systemd
  # user service, neither of which has the shell binaries on PATH — a bare
  # `dms`/`noctalia-shell` silently fails with "command not found", so locking
  # (lid-close, idle, before-sleep) never actually happens.
  lockCmd =
    if cfg.shell == "noctalia" then
      "${
        flakeInputs.noctalia.packages.${pkgs.system}.default
      }/bin/noctalia-shell ipc call lockScreen lock"
    else if cfg.shell == "dms" then
      "${config.programs.dank-material-shell.package}/bin/dms ipc call lock lock"
    else
      "${pkgs.swaylock}/bin/swaylock -f";

  # Lid-close lock helper. Locking on lid-close is the right default, EXCEPT
  # when an external display is connected (docked, or driving glasses): there
  # you keep using the external screen with the lid shut and don't want to be
  # locked out — often with no keyboard reachable to unlock. So skip the lock
  # whenever any non-eDP (external) DRM connector reports "connected".
  lidCloseLock = pkgs.writeShellScriptBin "niri-lid-close-lock" ''
    for s in /sys/class/drm/card*-*/status; do
      case "$s" in
        *eDP*) continue ;;
      esac
      if [ "$(cat "$s" 2>/dev/null)" = "connected" ]; then
        # External display present — keep the session usable with the lid shut.
        exit 0
      fi
    done
    exec ${pkgs.bash}/bin/bash -c ${lib.escapeShellArg lockCmd}
  '';

  oskToggle =
    if cfg.osk == "wvkbd" then
      pkgs.writeShellScriptBin "osk-toggle" ''
        set -eu
        # wvkbd-mobintl signal vocabulary (from main.c): SIGUSR1 hide,
        # SIGUSR2 show, SIGRTMIN toggle. SIGRTMIN+N has no handler → default
        # action terminates the process, so use plain SIGRTMIN here.
        ${pkgs.systemd}/bin/systemctl --user -q is-active wvkbd.service \
          || ${pkgs.systemd}/bin/systemctl --user start wvkbd.service
        ${pkgs.procps}/bin/pkill --signal SIGRTMIN wvkbd-mobintl
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

  config = lib.mkIf (config.lyte.desktop.enable && (config.lyte.desktop.niri.enable)) (
    lib.mkMerge [
      {
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
            # GTK4/libadwaita apps (ghostty, etc.) read their UI font + color-scheme
            # from the org.gnome.desktop.interface gsettings schema. On a GNOME/Plasma
            # host that schema comes for free; on niri-only it doesn't, so GTK apps
            # get no UI font (titlebar/tab text renders as tofu) and no dark/ayu
            # theming. Install the schemas explicitly so they land in the system
            # gschemas.compiled on the session's XDG_DATA_DIRS.
            gsettings-desktop-schemas
            glib # glib-compile-schemas / the gsettings CLI

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
          ++ [ lidCloseLock ]
          ++ lib.optional (cfg.osk != "none") oskToggle;

        # GTK4/libadwaita apps (ghostty, etc.) read their UI font + color-scheme
        # from the org.gnome.desktop.interface gsettings schema. On a niri-only host
        # that schema is not on the session's XDG_DATA_DIRS (GNOME/Plasma used to
        # put it there; programs.dconf.enable doesn't compile a combined schema on
        # this nixpkgs), so GTK apps get no UI font (titlebar/tab text = tofu) and no
        # dark/ayu theming. Append the schema dir to XDG_DATA_DIRS — same pattern
        # mobile.nix already uses for folks. (GTK looks in $XDG_DATA_DIRS/glib-2.0/schemas.)
        environment.sessionVariables.XDG_DATA_DIRS = [
          "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
        ];

        # Pick a Quickshell-based desktop shell. Both upstream modules launch the
        # shell as a systemd user unit; spawn-at-startup is no longer needed.
        # Both modules default their target to graphical-session.target, which
        # fires under *any* wayland session (including plasma). Bind to
        # niri.service so the shell only runs when niri is the live session.
        programs.noctalia = lib.mkIf (cfg.shell == "noctalia") {
          enable = true;
          package = flakeInputs.noctalia.packages.${pkgs.system}.default;
          systemd.enable = true;
          systemd.target = "niri.service";
        };
        programs.dank-material-shell = lib.mkIf (cfg.shell == "dms") {
          enable = true;
          systemd.enable = true;
          systemd.target = "niri.service";
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
              # KWin to be running — under niri it never produces frames.
              #
              # ScreenCast goes to xdg-desktop-portal-gnome: niri drives its own
              # window picker (niri msg pick-window / dynamic cast target) and
              # feeds frames through the gnome portal, which is the only backend
              # that exposes per-window capture under niri. xdg-desktop-portal-wlr
              # can only capture whole outputs (its window path needs
              # ext-image-copy-capture-v1, which niri doesn't implement yet).
              #
              # Screenshot stays on wlr (wlr-screencopy-unstable-v1, which niri
              # implements); we use grim/clipshot anyway.
              #
              # This is scoped to the `niri` desktop block on purpose — Plasma
              # sessions use the kde portal config and are unaffected.
              "org.freedesktop.impl.portal.ScreenCast" = "gnome";
              "org.freedesktop.impl.portal.Screenshot" = "wlr";
            };
          };
        };
        xdg.portal.extraPortals = [
          pkgs.xdg-desktop-portal-wlr
          pkgs.xdg-desktop-portal-gtk
          # Provides per-window ScreenCast capture under niri (see portal config
          # above). Only invoked in niri sessions; Plasma uses the kde portal.
          pkgs.xdg-desktop-portal-gnome
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

        # Niri user services (absorbed from HM)

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
          # GTK4/libadwaita apps read their UI font from here. The schema default is
          # "Adwaita Sans", which is only installed with GNOME — on a niri-only host
          # it's absent and GTK renders the titlebar/tab text as tofu boxes. Pin
          # IosevkaLyteTerm (installed, and matches the terminal font).
          font-name = "IosevkaLyteTerm 11";
          document-font-name = "IosevkaLyteTerm 11";
          monospace-font-name = "IosevkaLyteTerm 11";
        };
        lyte.userFiles = {
          ".config/gtk-3.0/settings.ini" = lib.mkForce ''
            [Settings]
            gtk-cursor-theme-name=Bibata-Modern-Classic
            gtk-cursor-theme-size=40
            gtk-theme-name=Adwaita
            gtk-font-name=IosevkaLyteTerm 11
            gtk-application-prefer-dark-theme=1
          '';
          ".config/gtk-4.0/settings.ini" = lib.mkForce ''
            [Settings]
            gtk-cursor-theme-name=Bibata-Modern-Classic
            gtk-cursor-theme-size=40
            gtk-theme-name=Adwaita
            gtk-font-name=IosevkaLyteTerm 11
            gtk-application-prefer-dark-theme=1
          '';
          # ayu palette override for GTK3 + GTK4/libadwaita apps.
          ".config/gtk-3.0/gtk.css" = ayuGtkCss;
          ".config/gtk-4.0/gtk.css" = ayuGtkCss;
        };

        # /etc/dconf/profile/user is what makes the dconf gsettings backend read the
        # user db (~/.config/dconf/user) — without it, dconf falls back to a bogus
        # profile and GTK apps see gsettings SCHEMA DEFAULTS instead of our values
        # (color-scheme=prefer-dark, font-name, ...), so nothing themed applied.
        # programs.dconf.enable is set but does NOT generate this profile on the
        # current nixpkgs, so provide it directly.
        environment.etc."dconf/profile/user".text = ''
          user-db:user
        '';

        # Symlinks for niri and ironbar config
        lyte.userSymlinks = {
          ".config/niri" = "${config.lyte.dotfilesPath}/niri";
          ".config/ironbar" = "${config.lyte.dotfilesPath}/ironbar";
        };
      }
      # Put the systemd user manager's PATH on the default environment so units
      # launched from the niri session find per-user/system binaries.
      #
      # nixpkgs-unstable (Jun 2026) removed systemd.user.extraConfig in favour of
      # systemd.user.settings.Manager; 26.05 stable still only has extraConfig.
      # optionalAttrs keeps the unavailable option's key out of the merge entirely
      # (a bare key for a non-existent option still errors, even with an empty
      # value), so exactly one of these contributes on either channel.
      (lib.optionalAttrs (options.systemd.user ? settings) {
        systemd.user.settings.Manager.DefaultEnvironment =
          ''"PATH=/run/current-system/sw/bin:/etc/profiles/per-user/%u/bin"'';
      })
      (lib.optionalAttrs (!(options.systemd.user ? settings)) {
        systemd.user.extraConfig = ''
          DefaultEnvironment="PATH=/run/current-system/sw/bin:/etc/profiles/per-user/%u/bin"
        '';
      })
    ]
  );
}
