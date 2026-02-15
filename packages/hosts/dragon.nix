{
  pkgs,
  config,
  hardware,
  diskoConfigurations,
  # homeConfigurations,
  ...
}:
{
  system.stateVersion = "24.11";
  networking = {
    hostName = "dragon";
    wifi.enable = true;
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.enable = true;
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "ahci"
      "usbhid"
    ];
    kernelModules = [ "kvm-amd" ];
    kernelParams = [
      "usbcore.autosuspend=-1"
    ];
    supportedFilesystems = [ "ntfs" ];
  };

  imports = with hardware; [
    (diskoConfigurations.unencrypted { disk = "/dev/nvme0n1"; })
    common-cpu-amd
    common-gpu-amd
    common-pc-ssd
  ];

  prevent-suspend.enable = true;
  hardware.bluetooth.enable = true;
  lyte.headscale.usePreAuthKey = true;
  powerManagement.cpuFreqGovernor = "performance";

  sops = {
    defaultSopsFile = ../../secrets/dragon/secrets.yml;
    secrets.ddns-pass.mode = "0400";
    secrets.nix-cache-priv-key.mode = "0400";
    secrets.claude-matrix-webhook = {
      sopsFile = ../../secrets/workstations/secrets.yml;
      mode = "0400";
      owner = "daniel";
    };
    secrets.claude-matrix-webhook-hive = {
      sopsFile = ../../secrets/workstations/secrets.yml;
      mode = "0400";
      owner = "daniel";
    };
    secrets.claude-matrix-webhook-code-review = {
      sopsFile = ../../secrets/workstations/secrets.yml;
      mode = "0400";
      owner = "daniel";
    };
  };

  services.deno-netlify-ddns-client = {
    enable = true;
    passwordFile = config.sops.secrets.ddns-pass.path;
    username = "dragon.h";
  };

  services.harmonia = {
    enable = true;
    signKeyPaths = [ config.sops.secrets.nix-cache-priv-key.path ];
  };

  networking.firewall.allowedTCPPorts = [
    4822
    5000
  ];

  programs.nix-ld.enable = true;

  services.postgresql.enable = true;
  # programs.steam.enable = true;
  lyte.desktop.enable = true;
  lyte.desktop.niri.enable = true;
  lyte.desktop.music-production = {
    enable = true;
    users = [ "daniel" ];
  };
  podman.enable = true;

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  home-manager.users.daniel = {
    lyte = {
      useOutOfStoreSymlinks.enable = true;
      shell = {
        enable = true;
        learn-jujutsu-not-git.enable = true;
      };
      desktop.enable = true;
      desktop.niri.enable = true;
      desktop.music-production.enable = true;
      push-to-talk.enable = true;
      claude.enable = true;
      claude.sfxPath = "${config.users.users.daniel.home}/Documents/wc3sfx/peon/sounds";
      claude.matrixWebhooks = {
        notify = config.sops.secrets.claude-matrix-webhook.path;
        hive = config.sops.secrets.claude-matrix-webhook-hive.path;
        code-review = config.sops.secrets.claude-matrix-webhook-code-review.path;
      };
    };
    slippi-launcher = {
      enable = true;
      isoPath = "${config.users.users.daniel.home}/../games/roms/dolphin/melee.iso";
      launchMeleeOnPlay = false;
    };
  };

  services.openssh.listenAddresses = [
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

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "riscv64-linux"
  ];

  # these are just scripts and so do not cause bloated nixos installations
  environment.systemPackages = with pkgs; [
    vibe
    mcpm-aider
    godot_4
  ];
}
