{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Sentinel for controller-driven exit from gaming mode. Steam's data dir is
  # bind-shared into the Flatpak sandbox at this same absolute path, so a
  # non-Steam "Exit Gaming Mode" shortcut that `touch`es it is seen here on the
  # host. A systemd .path unit watches it (event-driven — systemd's own inotify,
  # no polling and no idle process) and triggers the kill below.
  exitSentinel = "/home/daniel/.var/app/com.valvesoftware.Steam/.local/share/Steam/.foxtrot-exit-gamemode";

  gamemodeExit = pkgs.writeShellScript "foxtrot-gamemode-exit" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.procps
      ]
    }:/run/current-system/sw/bin:$PATH
    rm -f "${exitSentinel}"

    # PIDs of the gaming-mode gamescope: argv[0] basename exactly "gamescope"
    # (the live comm is "gamescope-wl", so match argv[0], not comm; this also
    # excludes the "gamescopereaper" helper) AND argv carries the Steam gamepadui
    # markers, so an unrelated gamescope is never matched.
    gm_pids() {
      for d in /proc/[0-9]*; do
        [ -r "$d/cmdline" ] || continue
        argv0=$(tr '\0' '\n' < "$d/cmdline" 2>/dev/null | head -n1)
        [ "$(basename "$argv0" 2>/dev/null)" = gamescope ] || continue
        cl=$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null)
        case "$cl" in
          *com.valvesoftware.Steam*-gamepadui*) echo "''${d#/proc/}" ;;
        esac
      done
    }

    # Graceful exit: ask Steam to shut down so it FINALIZES its appmanifests. An
    # abrupt kill leaves them dirty and Steam re-validates games on next launch —
    # notably Guild Wars 2, whose ArenaNet patcher already fights Steam over its
    # single 92GB Gw2.dat (StateFlags=4 yet a lingering ~1GB BytesToDownload).
    # Steam quitting collapses the nested gamescope back to niri on its own.
    flatpak run com.valvesoftware.Steam -shutdown >/dev/null 2>&1 || true

    # Wait for gamescope to fall away as Steam exits; fall back to terminating it
    # directly if Steam hasn't quit within the grace window.
    for _ in $(seq 1 30); do
      [ -z "$(gm_pids)" ] && exit 0
      sleep 1
    done
    for pid in $(gm_pids); do kill -TERM "$pid" 2>/dev/null || true; done
  '';
in
{
  imports = [
    ./foxtrot-viture-wake.nix
  ];

  system.stateVersion = "24.11";
  networking.hostName = "foxtrot";
  hardwareModules = [ "framework-13-7040-amd" ];
  diskConfig = {
    name = "standardWithHibernateSwap";
    params = {
      disk = "/dev/nvme0n1";
      swapSize = "32G";
    };
  };

  boot = {
    kernelParams = [
      "nowatchdog" # disable NMI watchdog to allow deeper C-states (minor power saving, not measure?)
      "amdgpu.abmlevel=3" # adaptive backlight management
    ];
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "thunderbolt"
    ];
    # uinput: Steam Input emits its virtual mouse/keyboard/gamepad through
    # /dev/uinput; the udev rule + input-group membership are already global
    # (default-module.nix), this just ensures the module is loaded.
    kernelModules = [
      "kvm-amd"
      "uinput"
    ];
    binfmt.emulatedSystems = [
      "aarch64-linux"
      "riscv64-linux"
    ];
  };

  hardware = {
    # Use nixpkgs' default bluez (no version pin). The previous 5.78
    # overrideAttrs was incidental cruft from a repo restructure, not a
    # deliberate fix. See the 2026 Steam Controller BT investigation: the
    # controller's ~70s cycling over Bluetooth is the bluez HID-over-GATT
    # GET_REPORT regression (bluez/bluez#880); if it still cycles in the
    # launch-then-connect flow on the default bluez, pin 5.73 (the only
    # fully-working version). The USB puck path is unaffected either way.
    bluetooth.enable = true;
  };

  # Temporarily disable kanidm-unixd on this host — the kanidm-posix
  # daniel (uid 2001) conflicts with the local daniel (uid 1000) for
  # login purposes: pam_kanidm accepts the shortname "daniel" at the
  # greeter and authenticates against the kanidm user, starting the
  # plasma session as uid 2001. OAuth2/SSO to web services is not
  # affected — that's beefcake-side and doesn't touch this host.
  # Re-enable once we've either removed daniel's posix extensions
  # from kanidm or arranged non-conflicting uids between the two.
  services.kanidm.client.enable = lib.mkForce false;

  programs.nix-ld.enable = true;

  # Let power-profiles-daemon manage the CPU governor via amd_pstate EPP
  services = {
    fwupd.extraRemotes = [ "lvfs-testing" ];
    power-profiles-daemon.enable = true;
    fprintd.enable = true;
    postgresql.enable = true;
  };

  systemd.services.fprintd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "simple";
  };

  # Event-driven controller exit from gaming mode: systemd watches the sentinel
  # the "Exit Gaming Mode" Steam shortcut touches (its own inotify — no polling,
  # no idle process) and runs the kill. The oneshot removes the sentinel, which
  # re-arms the .path for next time.
  systemd.user.paths.foxtrot-gamemode-exit = {
    description = "Watch for the Exit-Gaming-Mode sentinel";
    wantedBy = [ "graphical-session.target" ];
    pathConfig.PathExists = exitSentinel;
  };
  systemd.user.services.foxtrot-gamemode-exit = {
    description = "Quit gamescope gaming mode when the exit sentinel appears";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = gamemodeExit;
    };
  };

  # Use password (not fingerprint) for initial login so pam_gnome_keyring
  # can capture it and auto-unlock the login keyring. Without this, NM's
  # agent-owned wifi PSKs (and anything else in the keyring) prompt every
  # session and again on resume from suspend. Fingerprint stays on for
  # sudo / polkit / screen unlock, which only need re-auth, not the
  # password text.
  security.pam.services = {
    login.fprintAuth = false;
    plasmalogin.fprintAuth = false;
  };

  # Steam: install via flatpak (com.valvesoftware.Steam) — see
  # lib/doc/steam-flatpak-migration.md for the move from the old
  # nix-managed Steam library at ~/.local/share/Steam.
  # Keep the steam-hardware udev rules so Flatpak Steam still sees
  # Steam Controllers / Steam Deck dock correctly.
  hardware.steam-hardware.enable = true;

  # Host gamescope (with its CAP_SYS_NICE setcap wrapper). NB: the gamescope in
  # gaming.nix is gated on programs.steam.enable, which foxtrot doesn't set
  # (Steam is the flatpak) — so enable the upstream module directly here.
  programs.gamescope.enable = true;
  lyte = {
    editableConfigFiles = true;
    flakePath = "/etc/nix/flake";
    podman.enable = true;
    laptop.enable = true;
    family-account.enable = true;
    syncthing.enable = true;
    desktop = {
      displaylink.enable = true;
      niri.osk = "wvkbd";
      easyeffects = {
        enable = true;
        preset = "philonmetal";
        presetsSource = fetchGit {
          url = "https://github.com/ceiphr/ee-framework-presets";
          rev = "27885fe00c97da7c441358c7ece7846722fd12fa";
        };
      };
    };
    claude = {
      enable = true;
      sfxPath = "${config.lyte.userHome}/Documents/wc3sfx/peon/sounds";
      matrixWebhooks = {
        notify = config.sops.secrets.claude-matrix-webhook.path;
        hive = config.sops.secrets.claude-matrix-webhook-hive.path;
        code-review = config.sops.secrets.claude-matrix-webhook-code-review.path;
      };
    };
  };

  services.syncthing = {
    cert = config.sops.secrets.syncthing-cert.path;
    key = config.sops.secrets.syncthing-key.path;
  };

  sops.secrets =
    let
      workstationSecret = {
        sopsFile = ../../secrets/workstations/secrets.yml;
        mode = "0400";
        owner = "daniel";
        group = "users";
      };
      syncthingSecret = {
        sopsFile = ../../secrets/foxtrot/secrets.yml;
        mode = "0400";
        owner = "daniel";
        group = "users";
      };
    in
    {
      claude-matrix-webhook = workstationSecret;
      claude-matrix-webhook-hive = workstationSecret;
      claude-matrix-webhook-code-review = workstationSecret;
      syncthing-key = syncthingSecret;
      syncthing-cert = syncthingSecret;
    };

  # these are just scripts and so do not cause bloated nixos installations
  environment.systemPackages = with pkgs; [
    hidapi

    # "Gaming mode": one nested gamescope window hosting Steam in gamepad-UI, so
    # every game launched from it inherits gamescope isolation (clean cursor/
    # focus, native controller input) with NO per-game launch options. It's a
    # single niri toplevel — niri/overview stay underneath. Launch from the app
    # launcher or bind a niri key to `foxtrot-gamemode`.
    #
    # Sizes gamescope from the VITURE glasses' current mode when connected (gaming
    # mode is pinned there via niri open-on-output), falling back to the focused
    # output otherwise — so launching with the lid open doesn't render at the
    # laptop panel's resolution on the glasses. niri reports refresh in mHz;
    # falls back to 1080p60 if niri/jq aren't reachable. (The flatpak reaches
    # gamescope's nested Wayland socket fine — no --socket=wayland override.)
    #
    # Inhibits the screen lock AND idle suspend for the session: DMS's lock timer
    # is `enabled = acLockTimeout > 0` (and ignores the `dms ipc inhibit` flag),
    # but the actual idle daemon is swayidle — it runs the lock/suspend/dpms
    # timers and does NOT honor systemd-inhibit, so it must be stopped too.
    # Otherwise stepping away locks/suspends mid-session (controller input goes to
    # gamescope, not niri, so niri's idle timer keeps counting). Both restored on
    # exit.
    #
    # Controller-driven exit: gamescope's SteamOS "Switch to Desktop" is a no-op
    # on the Flatpak (it's a SteamOS-only session action Valve never wires up —
    # makes no D-Bus call, just hangs). Instead, a non-Steam "Exit Gaming Mode"
    # shortcut in the Steam library touches the exit sentinel; the
    # foxtrot-gamemode-exit.path unit watches it and quits gamescope, after which
    # the foreground gamescope below returns and the trap restores idle/lock. See
    # lib/doc/foxtrot-gaming-exit.md for the one-time shortcut setup.
    (writeShellScriptBin "foxtrot-gamemode" ''
      set -u
      export PATH=/run/current-system/sw/bin:$PATH
      export NIRI_SOCKET="''${NIRI_SOCKET:-$(ls "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/niri.wayland-*.sock 2>/dev/null | head -n1)}"
      # Prefer the glasses output (matched by model); else whatever's focused.
      out=$(niri msg --json outputs 2>/dev/null | jq -r 'to_entries[] | select(.value.model=="VITURE") | .key' 2>/dev/null | head -n1)
      [ -n "$out" ] || out=$(niri msg --json focused-output 2>/dev/null | jq -r '.name' 2>/dev/null)
      read -r W H R < <(
        niri msg --json outputs 2>/dev/null \
          | jq -r --arg o "$out" '.[$o] | .modes[.current_mode] | "\(.width) \(.height) \((.refresh_rate/1000)|round)"' 2>/dev/null
      ) || true
      : "''${W:=1920}" "''${H:=1080}" "''${R:=60}"
      [ "$R" -ge 20 ] 2>/dev/null || R=60
      echo "foxtrot-gamemode: gamescope output ''${W}x''${H}@''${R}Hz (output: ''${out:-?})" >&2

      # DMS drives two independent idle timers: acLockTimeout (screen lock) and
      # acMonitorTimeout (DPMS display-off). BOTH must be zeroed or the display
      # still sleeps mid-game. Plus swayidle (the lock/suspend/dpms daemon, which
      # ignores systemd-inhibit). Save + restore all three on exit.
      settings="$HOME/.config/DankMaterialShell/settings.json"
      saved_lock=$(jq -r '.acLockTimeout // 300' "$settings" 2>/dev/null)
      saved_mon=$(jq -r '.acMonitorTimeout // 180' "$settings" 2>/dev/null)
      case "$saved_lock" in "" | 0) saved_lock=300 ;; esac
      case "$saved_mon" in "" | 0) saved_mon=180 ;; esac
      idle_was=$(systemctl --user is-active swayidle 2>/dev/null || true)
      restore() {
        dms ipc call settings set acLockTimeout "$saved_lock" >/dev/null 2>&1 || true
        dms ipc call settings set acMonitorTimeout "$saved_mon" >/dev/null 2>&1 || true
        [ "$idle_was" = active ] && systemctl --user start swayidle >/dev/null 2>&1 || true
      }
      trap restore EXIT INT TERM
      dms ipc call settings set acLockTimeout 0 >/dev/null 2>&1 || true
      dms ipc call settings set acMonitorTimeout 0 >/dev/null 2>&1 || true
      systemctl --user stop swayidle >/dev/null 2>&1 || true

      # Clear any stale exit sentinel; foxtrot-gamemode-exit.path watches it and
      # kills this gamescope when the Exit Gaming Mode shortcut touches it, after
      # which this foreground gamescope returns and the trap restores idle/lock.
      rm -f "${exitSentinel}"

      gamescope -W "$W" -H "$H" -r "$R" -f -e -- \
        flatpak run com.valvesoftware.Steam -gamepadui "$@"
    '')

    # Desktop entry so "Gaming Mode" is launchable from the DMS launcher (or any
    # XDG app launcher) — the writeShellScriptBin above is CLI-only otherwise.
    (makeDesktopItem {
      name = "foxtrot-gamemode";
      desktopName = "Gaming Mode";
      comment = "Steam Big Picture in a nested gamescope session (clean controller/cursor)";
      exec = "foxtrot-gamemode";
      icon = "input-gaming";
      terminal = false;
      categories = [ "Game" ];
      keywords = [
        "steam"
        "gamescope"
        "gaming"
        "bigpicture"
      ];
    })
  ];
}
