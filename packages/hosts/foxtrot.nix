{
  pkgs,
  lib,
  config,
  ...
}:
let
  # Media / volume / brightness keys for the deckmode gaming session. gamescope
  # passes these keys straight through to Steam (which ignores them) and the
  # session has no desktop shell to bind them, so a tiny evdev daemon (triggerhappy)
  # handles them — started via services.deckmode.extraSessionCommands below. Scoped
  # to the gaming session only; a system-wide daemon would double-fire with DMS on
  # the niri desktop (every volume tap moving twice). Full binary paths since thd
  # runs commands via a bare shell; they inherit the session env (XDG_RUNTIME_DIR ->
  # wpctl finds PipeWire; the backlight is daniel-writable via the video group;
  # playerctl talks to the user bus for any MPRIS player).
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

  # Deck-like gaming mode: an on-demand gamescope + Steam session on its own VT
  # (vt7) you flip into and out of while niri keeps running on vt1 with all its
  # programs. Provided by the standalone deckmode module
  # (git.lyte.dev/lytedev/nixos-deckmode), wired in via packages/hosts/default.nix
  # extraModules. It stands up a second greetd instance on vt7, an on-demand
  # launcher (switches to vt7 if already running), a controller-reachable stop
  # (sentinel + root watcher), Restart=no + ExecStopPost=chvt so a crash/quit never
  # respawns or strands you, and a desktop notification on exit.
  #
  # - steam.enable = false: foxtrot enables programs.steam (+ programs.gamescope via
  #   gaming.nix) itself below, so let it own those rather than deckmode's defaults.
  # - inhibitLidSwitch: hold a handle-lid-switch inhibitor for the session's life so
  #   closing the lid while gaming on the glasses doesn't suspend (also flips
  #   services.logind LidSwitchIgnoreInhibited=no so the inhibitor is respected).
  # - extraSessionCommands: foxtrot-specific media/volume/brightness keys via a
  #   triggerhappy daemon (see gamingKeyTriggers above).
  services.deckmode = {
    enable = true;
    user = "daniel";
    inhibitLidSwitch = true;
    steam.enable = false;
    launcher = {
      name = "Gaming Mode (glasses)";
      stopName = "Exit Gaming Mode (glasses)";
    };
    extraSessionCommands = ''
      # Hand thd only KEYBOARD-CLASS devices: it chokes on the controller's motion
      # sensors ("not suitable") and on the raw /dev/input/event* glob. Select
      # devices that expose EV_KEY but aren't gamepads — the AT keyboard
      # (volume/mute) + the Framework "Consumer Control" device (brightness).
      # daniel is in `input`. Backgrounded; the session cgroup reaps it on exit.
      keydevs=""
      for e in /dev/input/event*; do
        p=$(udevadm info -q property -n "$e" 2>/dev/null) || continue
        case "$p" in *ID_INPUT_KEY=1*) ;; *) continue ;; esac
        case "$p" in *ID_INPUT_JOYSTICK=1*) continue ;; esac
        keydevs="$keydevs $e"
      done
      ${pkgs.triggerhappy}/bin/thd --triggers ${gamingKeyTriggers} $keydevs &
    '';
  };

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
  # game<->Steam focus switching) never work. System Steam embeds in a seated
  # gamescope properly (which is what deckmode gives it on vt7).
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
  # nounwind extern-"C" XTest shim (SIGABRT, confirmed). The working path is the
  # seated gamescope session deckmode provides, where gamescope owns the seat and
  # Steam Input drives the cursor natively — no extest. So leave it OFF.
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
  ];
}
