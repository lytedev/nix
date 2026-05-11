{
  lib,
  pkgs,
  config,
  ...
}:
{
  system.stateVersion = "24.11";
  networking = {
    hostName = "dragon";
    wifi.enable = true;
  };

  hardwareModules = [
    "common-cpu-amd"
    "common-pc-ssd"
  ];
  diskConfig = {
    name = "unencrypted";
    params.disk = "/dev/nvme0n1";
  };

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "ahci"
      "usbhid"
    ];
    kernelModules = [ "kvm-amd" ];
    kernelParams = [ "usbcore.autosuspend=-1" ];
    supportedFilesystems = [ "ntfs" ];
    binfmt.emulatedSystems = [
      "aarch64-linux"
      "riscv64-linux"
    ];
  };

  # zram swap as a pressure relief valve for earlyoom — gives the kernel
  # somewhere to page inactive memory so earlyoom has time to act
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  hardware.bluetooth.enable = true;
  powerManagement.cpuFreqGovernor = "performance";

  sops = {
    defaultSopsFile = ../../secrets/dragon/secrets.yml;
    secrets =
      let
        danielSecret = {
          mode = "0400";
          owner = "daniel";
          group = "users";
        };
        workstationSecret = danielSecret // {
          sopsFile = ../../secrets/workstations/secrets.yml;
        };
        syncthingSecret = danielSecret;
      in
      {
        ddns-pass.mode = "0400";
        nix-cache-priv-key.mode = "0400";
        claude-matrix-webhook = workstationSecret;
        claude-matrix-webhook-hive = workstationSecret;
        claude-matrix-webhook-code-review = workstationSecret;
        slack-user-token = danielSecret;
        notion-token = danielSecret;
        syncthing-key = syncthingSecret;
        syncthing-cert = syncthingSecret;
      };
  };

  services.syncthing = {
    cert = config.sops.secrets.syncthing-cert.path;
    key = config.sops.secrets.syncthing-key.path;
  };

  services = {
    deno-netlify-ddns-client = {
      enable = true;
      passwordFile = config.sops.secrets.ddns-pass.path;
      username = "dragon.h";
    };
    harmonia = {
      enable = true;
      signKeyPaths = [ config.sops.secrets.nix-cache-priv-key.path ];
    };
    postgresql.enable = true;
    sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
      openFirewall = true;
    };
    openssh.listenAddresses = [
      {
        addr = "[::]";
        port = 4822;
      }
      {
        addr = "0.0.0.0";
        port = 4822;
      }
      {
        addr = "[::]";
        port = 22;
      }
      {
        addr = "0.0.0.0";
        port = 22;
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [
    4822
    5000
  ];

  programs.nix-ld.enable = true;
  # programs.steam.enable = true;

  # Steam: install via flatpak (com.valvesoftware.Steam). Keep the
  # steam-hardware udev rules so Flatpak Steam can access Steam
  # Controllers (incl. the 2026 controller / Puck dongle, 28de:1304)
  # and the Steam Deck dock — without these, the hidraw nodes are
  # root:root 600 and Flatpak Steam can't open them.
  hardware.steam-hardware.enable = true;

  # Temporarily disable kanidm-unixd on this host — the kanidm-posix
  # daniel (uid 2001) conflicts with the local daniel (uid 1000) for
  # login purposes: pam_kanidm accepts the shortname "daniel" at the
  # greeter and authenticates against the kanidm user, starting the
  # plasma session as uid 2001. OAuth2/SSO to web services is not
  # affected — that's beefcake-side and doesn't touch this host.
  # Re-enable once we've either removed daniel's posix extensions
  # from kanidm or arranged non-conflicting uids between the two.
  services.kanidm.client.enable = lib.mkForce false;

  lyte = {
    editableConfigFiles = true;
    flakePath = "/etc/nix/flake";
    podman.enable = true;
    server.enable = true;
    server.logs.enable = false;
    headscale.usePreAuthKey = true;
    desktop.enable = true;
    desktop.voxtype.model = "large-v3-turbo";
    gpu = "amd";
    desktop.music-production = {
      enable = true;
      users = [ "daniel" ];
    };
    syncthing.enable = true;
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

  # these are just scripts and so do not cause bloated nixos installations
  environment.systemPackages = with pkgs; [
    playwright-mcp
    godot_4
    hidapi
  ];
}
