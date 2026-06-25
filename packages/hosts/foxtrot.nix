{
  pkgs,
  lib,
  config,
  ...
}:
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
    kernelModules = [ "kvm-amd" ];
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
  lyte = {
    editableConfigFiles = true;
    flakePath = "/etc/nix/flake";
    podman.enable = true;
    laptop.enable = true;
    family-account.enable = true;
    syncthing.enable = true;
    desktop = {
      displaylink.enable = true;
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
  ];
}
