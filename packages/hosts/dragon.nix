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
    secrets.slack-user-token = {
      mode = "0400";
      owner = "daniel";
    };
    secrets.notion-token = {
      mode = "0400";
      owner = "daniel";
    };
    secrets.opencode-server-password = {
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

  sops.templates."opencode-env" = {
    owner = "daniel";
    content = ''
      NOTION_TOKEN=${config.sops.placeholder.notion-token}
      OPENCODE_SERVER_PASSWORD=${config.sops.placeholder.opencode-server-password}
    '';
  };
  lyte.opencode = {
    enable = true;
    package = pkgs.opencode.overrideAttrs (old: rec {
      version = "1.2.15";
      src = old.src.override {
        tag = "v${version}";
        hash = "sha256-26MV9TbyAF0KFqZtIHPYu6wqJwf0pNPdW/D3gDQEUlQ=";
      };
      node_modules = old.node_modules.overrideAttrs (nmOld: {
        inherit src;
        outputHash = "sha256-Diu/C8b5eKUn7MRTFBcN5qgJZTp0szg0ECkgEaQZ87Y=";
      });
    });
    environmentFiles = [ config.sops.templates."opencode-env".path ];
  };
  lyte.shell.enable = true;
  lyte.push-to-talk.enable = true;
  lyte.claude = {
    enable = true;
    sfxPath = "${config.users.users.daniel.home}/Documents/wc3sfx/peon/sounds";
    matrixWebhooks = {
      notify = config.sops.secrets.claude-matrix-webhook.path;
      hive = config.sops.secrets.claude-matrix-webhook-hive.path;
      code-review = config.sops.secrets.claude-matrix-webhook-code-review.path;
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
