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
    package =
      let
        src = pkgs.fetchFromGitHub {
          owner = "lytedev";
          repo = "opencode";
          rev = "a7c12666d7d0079eb86dd2aed228bd4f79b6bbf2";
          hash = "sha256-cNtwjiuG2kJVPfRitC2aVkIgwssDhLsaxjctq9M/RLY=";
        };
        node_modules = pkgs.opencode.node_modules.overrideAttrs (_: {
          inherit src;
          outputHash = "sha256-Jdo3ktUIWBKosVmkeBr/E5Je0VHVxfUaSAbWshFZT9s=";
        });
        # Build the Vite app in a sandbox-safe derivation using the node_modules FOD
        # (which already includes packages/app/node_modules with vite)
        app_dist = pkgs.stdenvNoCC.mkDerivation {
          name = "opencode-app-dist-dev";
          inherit src;
          nativeBuildInputs = [ pkgs.bun ];
          buildPhase = ''
            # Symlinks in packages/*/node_modules point up to ../../node_modules/.bun/
            # Copy the entire FOD over the source tree so all relative symlinks resolve
            cp -r ${node_modules}/. .
            chmod -R u+w node_modules packages
            cd packages/app
            bun run node_modules/vite/bin/vite.js build
          '';
          installPhase = ''
            cp -r dist $out
          '';
        };
      in
      pkgs.opencode.overrideAttrs (old: {
        version = "0.0.0-dev";
        inherit src;
        node_modules = node_modules;
        # Inject pre-built app dist so --skip-app-build works in the sandbox
        preBuild = ''
          cp -r ${app_dist} packages/app/dist
          chmod -R u+w packages/app/dist
        '';
        buildPhase = ''
          runHook preBuild
          cd ./packages/opencode
          bun --bun ./script/build.ts --single --skip-install --skip-app-build
          bun --bun ./script/schema.ts schema.json
          runHook postBuild
        '';
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
    opencode
    vibe
    mcpm-aider
    godot_4
  ];
}
