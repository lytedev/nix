{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Sentinel for controller-driven exit from gaming mode. It lives in Steam's
  # data dir, so a non-Steam "Exit Gaming Mode" shortcut that `touch`es it (path
  # relative to Steam's install dir) is seen here on the host. A systemd .path
  # unit watches it (event-driven — systemd's own inotify, no polling and no idle
  # process) and triggers the kill below.
  exitSentinel = "/home/daniel/.local/share/Steam/.foxtrot-exit-gamemode";

  # Sentinel for stopping the CONCURRENT gaming session (greetd-gaming on vt7) from
  # inside Steam. A non-Steam library shortcut touches it (works from Steam's bwrap
  # sandbox — just a file write); a ROOT systemd .path watches it and does the
  # privileged part (chvt back to niri + systemctl stop greetd-gaming), which the
  # sandbox itself can't (NoNewPrivileges blocks a cap-wrapped chvt).
  stopGamingSentinel = "/home/daniel/.local/share/Steam/.foxtrot-gaming-vt-stop";

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
          *steam*-gamepadui*) echo "''${d#/proc/}" ;;
        esac
      done
    }

    # Graceful exit: ask Steam to shut down so it FINALIZES its appmanifests. An
    # abrupt kill leaves them dirty and Steam re-validates games on next launch —
    # notably Guild Wars 2, whose ArenaNet patcher already fights Steam over its
    # single 92GB Gw2.dat (StateFlags=4 yet a lingering ~1GB BytesToDownload).
    # Steam quitting collapses the nested gamescope back to niri on its own.
    steam -shutdown >/dev/null 2>&1 || true

    # Wait for gamescope to fall away as Steam exits; fall back to terminating it
    # directly if Steam hasn't quit within the grace window.
    for _ in $(seq 1 30); do
      [ -z "$(gm_pids)" ] && exit 0
      sleep 1
    done
    for pid in $(gm_pids); do kill -TERM "$pid" 2>/dev/null || true; done
  '';

  # "Gaming (gamescope)" session: a wayland-session entry the display manager
  # (plasma-login-manager) launches SEATED, exactly like it launches niri. On its
  # own DRM seat gamescope owns input, so Steam Input drives the cursor natively
  # (the Steam Deck model) — the only way to get controller-as-mouse. Nested in
  # niri, gamescope doesn't own the seat and Steam falls back to XTest (frozen
  # cursor). Letting the DM do the seating also means Steam runs in a real login
  # session, so its bwrap/runtime works (a hand-rolled systemd seat broke it).
  # Pick this session at the greeter to game; exit returns to the greeter for niri.
  # Media / volume / brightness keys for the gaming session. gamescope passes these
  # keys straight through to Steam (which ignores them) and this session has no
  # desktop shell to bind them, so a tiny evdev daemon (triggerhappy) handles them.
  # Scoped to the gaming session only — a system-wide daemon would double-fire with
  # DMS on the niri desktop (every volume tap moving twice). Full binary paths since
  # thd runs commands via a bare shell; they inherit this session's env
  # (XDG_RUNTIME_DIR → wpctl finds PipeWire; the backlight is daniel-writable via
  # the video group; playerctl talks to the user bus for any MPRIS player).
  gamingKeyTriggers = pkgs.writeText "foxtrot-gaming-keys.conf" ''
    KEY_VOLUMEUP       1  ${pkgs.wireplumber}/bin/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
    KEY_VOLUMEDOWN     1  ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    KEY_MUTE           1  ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    KEY_BRIGHTNESSUP   1  ${pkgs.brightnessctl}/bin/brightnessctl set 5%+
    KEY_BRIGHTNESSDOWN 1  ${pkgs.brightnessctl}/bin/brightnessctl set 5%-
    KEY_PLAYPAUSE      1  ${pkgs.playerctl}/bin/playerctl play-pause
    KEY_NEXTSONG       1  ${pkgs.playerctl}/bin/playerctl next
    KEY_PREVIOUSSONG   1  ${pkgs.playerctl}/bin/playerctl previous
  '';
  gamingSessionScript = pkgs.writeShellScript "foxtrot-gaming-session" ''
    export PATH=/run/current-system/sw/bin:$PATH

    # Media/volume/brightness keys for the session lifetime (see gamingKeyTriggers).
    # Hand thd only KEYBOARD-CLASS devices: thd chokes on non-key devices (the
    # controller's motion sensors report "not suitable"), and passing the raw
    # /dev/input/event* glob then breaks its reads. Select devices that expose
    # EV_KEY but aren't gamepads — that's the AT keyboard (volume/mute) + the
    # Framework "Consumer Control" device (brightness). daniel is in `input`.
    keydevs=""
    for e in /dev/input/event*; do
      p=$(udevadm info -q property -n "$e" 2>/dev/null) || continue
      case "$p" in *ID_INPUT_KEY=1*) ;; *) continue ;; esac
      case "$p" in *ID_INPUT_JOYSTICK=1*) continue ;; esac
      keydevs="$keydevs $e"
    done
    ${pkgs.triggerhappy}/bin/thd --triggers ${gamingKeyTriggers} $keydevs &
    thd_pid=$!
    trap 'kill "$thd_pid" 2>/dev/null || true' EXIT

    # Keep the session awake for gamescope's life: idle+sleep (laptop.nix sets
    # IdleAction=suspend at 11m) AND handle-lid-switch — so closing the lid while
    # gaming on the glasses doesn't suspend. The lid inhibitor only bites because
    # this host sets LidSwitchIgnoreInhibited=no (below); it's released when the
    # gaming session ends, so normal lid-close still suspends otherwise.
    # --backend drm: drive the displays directly on this session's seat.
    systemd-inhibit --what=idle:sleep:handle-lid-switch --who=gaming --why="gaming on the glasses" \
      gamescope --backend drm -e -- steam -gamepadui > "$HOME/.foxtrot-gaming.log" 2>&1
  '';
  gamingSessionPackage =
    (pkgs.writeTextFile {
      name = "foxtrot-gaming-session";
      destination = "/share/wayland-sessions/foxtrot-gaming.desktop";
      text = ''
        [Desktop Entry]
        Name=Gaming (gamescope)
        Comment=Steam Big Picture in a seated gamescope session (controller-native)
        Exec=${gamingSessionScript}
        Type=Application
        DesktopNames=gamescope
      '';
    }).overrideAttrs
      (_: {
        passthru.providedSessions = [ "foxtrot-gaming" ];
      });

  # Concurrent gaming: a SECOND greetd instance that autologins daniel into the
  # same seated gamescope session on its OWN vt (7), so it can run alongside the
  # niri session on vt1 — Ctrl+Alt+F7 into full controller-mouse gaming, Ctrl+Alt+F1
  # back to niri with every program still running. greetd (not a hand-rolled systemd
  # unit) gives a proper PAM login so Steam's bwrap works. On-demand: the
  # greetd-gaming.service is not started at boot.
  gamingGreetdConfig = pkgs.writeText "greetd-gaming.toml" ''
    [terminal]
    vt = 7

    [default_session]
    command = "${gamingSessionScript}"
    user = "daniel"
  '';

  # Controller-reachable exit from gaming mode. Steam's own "Switch to Desktop" is
  # a NO-OP here — verified live on both flatpak AND system Steam: it never shells
  # out to steamos-session-select, so the stub below is never reached. The working
  # exit is this helper added ONCE as a non-Steam library shortcut ("Add a
  # Non-Steam Game" -> point it at /run/current-system/sw/bin/foxtrot-exit-gamemode).
  # Clicking it in Big Picture (controller-navigable) touches the exit sentinel ->
  # the foxtrot-gamemode-exit.path watcher quits Steam + kills gamescope -> greetd
  # returns to the ReGreet greeter, where niri is picked. A real touch binary
  # (not /usr/bin/touch, which doesn't exist on NixOS) and the system-Steam
  # sentinel path.
  exitGamemode = pkgs.writeShellScriptBin "foxtrot-exit-gamemode" ''
    exec ${pkgs.coreutils}/bin/touch "${exitSentinel}"
  '';

  # Kept as a fallback in case a future Steam/gamescope build DOES call
  # steamos-session-select on "Switch to Desktop": any non-gamescope target ends
  # the session via the same sentinel. (Logs the arg so we can tell if it ever
  # fires.) As of 2026-06-30 it never does — use exitGamemode above.
  steamosSessionSelect = pkgs.writeShellScriptBin "steamos-session-select" ''
    echo "steamos-session-select $* @ $(date)" >> "$HOME/.foxtrot-session-select.log"
    case "''${1:-}" in
      gamescope | "") : ;; # staying in game mode -> no-op
      *) touch "${exitSentinel}" ;; # any desktop target -> exit gaming mode
    esac
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
    # Respect lid-switch inhibitors, so the gaming session can hold one and closing
    # the lid while gaming on the glasses doesn't suspend. laptop.nix leaves this
    # default-on (lid ignores inhibitors — "don't melt in a bag"); flipping it means
    # ONLY an active inhibitor changes behavior — a plain lid-close still suspends.
    logind.settings.Login.LidSwitchIgnoreInhibited = false;
    # Secret Service. It's already running here, but only the GNOME desktop path
    # enables it in this repo — with Plasma removed, pin it explicitly so the
    # login keyring (pam_gnome_keyring capture, libsecret consumers) survives.
    # NetworkManager wifi PSKs are stored plaintext in system-connections, so
    # they don't depend on this either way.
    gnome.gnome-keyring.enable = true;
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
    # default.target, NOT graphical-session.target: niri/DMS never starts
    # graphical-session.target on foxtrot (verified inactive even in a live niri
    # session), so a unit wanted by it is never armed — the exit watcher was dead.
    # default.target is active in every logged-in user session (niri AND the bare
    # gamescope gaming session), so the sentinel is actually watched.
    wantedBy = [ "default.target" ];
    pathConfig.PathExists = exitSentinel;
  };
  systemd.user.services.foxtrot-gamemode-exit = {
    description = "Quit gamescope gaming mode when the exit sentinel appears";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = gamemodeExit;
    };
  };

  # Register the "Gaming (gamescope)" wayland-session so it appears in the
  # display manager's session picker. The DM seats it like any other session.
  services.displayManager.sessionPackages = [ gamingSessionPackage ];

  # Second greetd instance for the concurrent gaming session on vt7 (see
  # gamingGreetdConfig). Not wanted by any target — started on demand
  # (`systemctl start greetd-gaming`), then Ctrl+Alt+F7 to switch to it.
  # Restart=no: this is an on-demand, explicitly-killable session. gamescope tends
  # to crash when you switch AWAY from its VT (a documented gamescope-on-a-separate-
  # TTY caveat), and that crash is an autonomous exit — with Restart=always systemd
  # would respawn it 2s later and yank you straight back to vt7, so "switch/exit to
  # desktop" could never actually leave. We're fine with the session dying on exit
  # (niri and its programs are preserved on vt1); relaunch to game again.
  systemd.services.greetd-gaming = {
    description = "Concurrent gamescope gaming session (greetd, vt7)";
    serviceConfig = {
      ExecStart = "${config.services.greetd.package}/bin/greetd --config ${gamingGreetdConfig}";
      Restart = "no";
      # Whenever the gaming session ends for ANY reason — clean stop, Steam quit,
      # or gamescope crash — switch back to niri on vt1. Without this, killing Steam
      # while on vt7 strands you on a dead compositor-less VT that a controller
      # (no Ctrl+Alt+F1) can't escape. Runs as root on every exit path.
      ExecStopPost = "${pkgs.kbd}/bin/chvt 1";
    };
    restartIfChanged = false;
  };

  # Let daniel start/stop the concurrent gaming session (greetd-gaming.service)
  # from the desktop launcher without a root prompt.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "greetd-gaming.service" &&
          subject.user == "daniel") {
        return polkit.Result.YES;
      }
    });
  '';
  # Use password (not fingerprint) for initial login so pam_gnome_keyring
  # can capture it and auto-unlock the login keyring. Without this, NM's
  # agent-owned wifi PSKs (and anything else in the keyring) prompt every
  # session and again on resume from suspend. Fingerprint stays on for
  # sudo / polkit / screen unlock, which only need re-auth, not the
  # password text. (greetd's fprintAuth is set by lib/modules/nixos/greeter.nix.)
  security.pam.services.login.fprintAuth = false;

  # Steam: nix-managed (programs.steam), NOT flatpak. The Flatpak Steam's sandbox
  # always binds the host (niri) display sockets, so a host gamescope can never
  # contain it — Steam escapes onto niri's display and the SteamOS behaviors
  # (Steam-button overlay, controller-as-mouse, single-surface fullscreen,
  # game<->Steam focus switching) never work. System Steam embeds in the nested
  # gamescope properly. See lib/doc/steam-flatpak-migration.md (now reversed) for
  # the library move (~/.var/app/.../Steam -> ~/.local/share/Steam).
  #
  # programs.steam.enable pulls in lib/modules/nixos/gaming.nix (gated on it):
  # gamescope + its CAP_SYS_NICE setcap wrapper, steam-hardware udev (Steam
  # Controller / Deck dock), 32-bit graphics, proton-ge, esync fd limits, and
  # extest disabled (gamescope handles controller input natively).
  programs.steam.enable = true;

  # 2026 Steam Controller (28DE:1303) over Bluetooth enumerates as a uhid device,
  # and the steam-hardware BT uaccess rule (KERNELS=="*28DE:*") doesn't land on it
  # — its hidraw stays root:root 0600, so system Steam can't claim the controller
  # out of kernel "lizard mode" (keyboard/mouse) into Steam Input, and the Steam
  # button never opens the overlay in gaming mode. Grant the input group (daniel)
  # access (+ uaccess) so Steam can open it. Verified live: this flips the hidraw
  # to root:input 0660 and daniel can read it.
  services.udev.extraRules = ''
    KERNEL=="hidraw*", KERNELS=="*28DE:1303*", MODE="0660", GROUP="input", TAG+="uaccess"
  '';

  # Controller-as-mouse on Wayland: Steam Input's mouse emulation injects motion
  # via XTest, which warps the X11 logical pointer (apps react, cursor shape
  # changes) but NOT the Wayland/gamescope pointer that draws the visible cursor
  # — so with a controller the sprite stays frozen while a real trackpad moves it
  # fine. `extest` (the XTest->Wayland shim) is the obvious bridge, BUT it was
  # tried here on 2026-06-29 with Steam running INSIDE gamescope (so a Wayland
  # compositor IS present) and it STILL aborts: the 32-bit ubuntu12_32/steam
  # client SIGABRTs the instant Steam Input injects motion (coredump confirmed).
  # ROOT CAUSE (investigated 2026-06-29): the nixpkgs lib is 32-bit-only, so it
  # loads ONLY into the 32-bit Steam bootstrap client (64-bit procs reject it —
  # the ELFCLASS32 spam). On the first injected motion, extest lazily builds an
  # absolute uinput pointer sized from Wayland xdg-output, with `.unwrap()` at
  # every step — but that bootstrap client, inside the Steam runtime
  # (pressure-vessel) container nested in gamescope, has no usable Wayland /
  # xdg-output global, so it panics and the panic abort()s Steam across extest's
  # nounwind extern-"C" XTest shim (SIGABRT, confirmed). extest assumes Steam on a
  # bare wlroots desktop, not nested in gamescope inside pressure-vessel — it's
  # architecturally mismatched here and tested-dead even with `-steamos3`. The real
  # fix is a proper gamescope SESSION (Jovian steamos-session-select, desktop=niri)
  # where Steam Input drives the cursor natively, no extest. So leave it OFF.
  # programs.steam.extest.enable = lib.mkForce true;  # SIGABRTs Steam — see above
  lyte = {
    editableConfigFiles = true;
    flakePath = "/etc/nix/flake";
    podman.enable = true;
    laptop.enable = true;
    family-account.enable = true;
    syncthing.enable = true;
    desktop = {
      # niri, not Plasma. Drop the Plasma desktop / apps / display-manager /
      # kwallet entirely — niri already provides dconf, xdg portals, and the
      # polkit agent, gnome-keyring (pinned below) is the Secret Service, and the
      # greeter is greetd/ReGreet. Dolphin (the one KDE app kept) is added back
      # explicitly below. niri.enable still defaults on via lyte.desktop.enable.
      plasma.enable = false;
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

    # Keep the KDE file manager after dropping the rest of Plasma. dolphin pulls
    # its own kio; kio-extras adds the extra kioworkers (mtp/sftp/archive/etc.)
    # and breeze-icons keeps its toolbar/mimetype icons from rendering blank
    # without the Plasma icon theme installed.
    kdePackages.dolphin
    kdePackages.kio-extras
    kdePackages.breeze-icons

    # Also install the gaming-session .desktop into the system path's
    # share/wayland-sessions/, alongside sessionPackages above — the greeter
    # (lib/modules/nixos/greeter.nix) points ReGreet's XDG_DATA_DIRS at
    # services.displayManager.sessionData.desktops, which is how "Gaming
    # (gamescope)" actually shows up in the picker; this system-path copy is
    # kept for anything else that reads the default XDG_DATA_DIRS.
    gamingSessionPackage

    # Controller-reachable game-mode exit: add as a non-Steam library shortcut.
    # (Steam's "Switch to Desktop" is a no-op here, so this is the real exit.)
    exitGamemode
    # Fallback stub in case a future Steam build DOES call steamos-session-select.
    steamosSessionSelect

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
    # falls back to 1080p60 if niri/jq aren't reachable. System Steam connects to
    # gamescope's nested Wayland display directly (unlike the Flatpak, whose
    # sandbox bound niri's sockets and escaped gamescope entirely).
    #
    # Inhibits the screen lock AND idle suspend for the session: DMS's lock timer
    # is `enabled = acLockTimeout > 0` (and ignores the `dms ipc inhibit` flag),
    # but the actual idle daemon is swayidle — it runs the lock/suspend/dpms
    # timers and does NOT honor systemd-inhibit, so it must be stopped too.
    # Otherwise stepping away locks/suspends mid-session (controller input goes to
    # gamescope, not niri, so niri's idle timer keeps counting). Both restored on
    # exit.
    #
    # Controller-driven exit: Steam's "Switch to Desktop" expects a real SteamOS
    # gamescope-session to switch to, which a nested gamescope launched from niri
    # is not — so it's a no-op here. Instead, a non-Steam "Exit Gaming Mode"
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

      # Steam is single-instance: if a desktop Steam is already running,
      # `steam -gamepadui` just signals THAT instance to switch to Big Picture on
      # the niri desktop and our gamescope child exits immediately (gamescope
      # quits with an empty window). So fully quit any running Steam first.
      # `steam -shutdown` alone can take longer than we want (and sometimes
      # doesn't land), so wait briefly then SIGKILL the stragglers + the runtime.
      if pgrep -u "$(id -u)" -x steamwebhelper >/dev/null 2>&1; then
        echo "foxtrot-gamemode: quitting the running desktop Steam first" >&2
        steam -shutdown >/dev/null 2>&1 || true
        for _ in $(seq 1 20); do
          pgrep -u "$(id -u)" -x steamwebhelper >/dev/null 2>&1 || break
          sleep 1
        done
        pkill -u "$(id -u)" -9 -x steamwebhelper 2>/dev/null || true
        pkill -u "$(id -u)" -9 -f ubuntu12_ 2>/dev/null || true
        sleep 2
      fi

      gamescope -W "$W" -H "$H" -r "$R" -f -e -- \
        steam -gamepadui "$@"
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

    # Concurrent gaming (vt7): start on-demand (auto-switches to vt7; niri keeps
    # running on vt1). Launch from the DMS/app launcher.
    (writeShellScriptBin "foxtrot-gaming-start" ''
      # If the gaming session is already up on vt7, just switch to it (starting an
      # already-active unit is a no-op and wouldn't flip the VT). daniel's session
      # is allowed to chvt via logind (org.freedesktop.login1.chvt allow_active=yes).
      if ${pkgs.systemd}/bin/systemctl is-active --quiet greetd-gaming.service; then
        exec ${pkgs.systemd}/bin/busctl call org.freedesktop.login1 \
          /org/freedesktop/login1/seat/seat0 org.freedesktop.login1.Seat SwitchTo u 7
      else
        # Fresh start auto-switches to vt7.
        exec ${pkgs.systemd}/bin/systemctl start greetd-gaming.service
      fi
    '')
    (makeDesktopItem {
      name = "foxtrot-gaming-vt";
      desktopName = "Gaming Mode (glasses)";
      comment = "Full-controller gamescope on its own VT; niri keeps running (Ctrl+Alt+F1 returns)";
      exec = "foxtrot-gaming-start";
      icon = "input-gaming";
      terminal = false;
      categories = [ "Game" ];
    })
    # Return to niri + kill the gaming session. Just touches the sentinel (works
    # from Steam's bwrap sandbox); the root watcher below does chvt + stop. Add as a
    # non-Steam library shortcut for a controller-only "Switch to Desktop", or run
    # from the niri launcher.
    (writeShellScriptBin "foxtrot-gaming-stop" ''
      exec ${pkgs.coreutils}/bin/touch "${stopGamingSentinel}"
    '')
    (makeDesktopItem {
      name = "foxtrot-gaming-stop";
      desktopName = "Exit Gaming Mode (glasses)";
      comment = "Return to niri and kill the concurrent gaming session";
      exec = "foxtrot-gaming-stop";
      icon = "application-exit";
      terminal = false;
      categories = [ "Game" ];
    })
  ];

  # Root-side watcher for the stop sentinel: chvt back to niri (vt1) then stop the
  # concurrent gaming session. Root so it can chvt + manage the system unit (the
  # Steam sandbox can't). Event-driven via the .path unit.
  systemd.paths.foxtrot-gaming-vt-stop = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathExists = stopGamingSentinel;
  };
  systemd.services.foxtrot-gaming-vt-stop = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "foxtrot-gaming-vt-stop" ''
        ${pkgs.coreutils}/bin/rm -f "${stopGamingSentinel}"
        ${pkgs.kbd}/bin/chvt 1 || true
        if ${pkgs.systemd}/bin/systemctl stop greetd-gaming.service; then
          body="Back at the desktop; gaming session closed."
          urgency=normal
        else
          body="Something went wrong stopping the gaming session."
          urgency=critical
        fi
        # Notify in daniel's niri session (runs as root; hop to daniel + the session bus).
        ${pkgs.util-linux}/bin/runuser -u daniel -- \
          env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
          ${pkgs.libnotify}/bin/notify-send -a "Gaming Mode" -u "$urgency" "Gaming Mode" "$body" || true
      '';
    };
  };
}
