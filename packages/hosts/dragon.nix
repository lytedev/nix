{
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

  hardware.bluetooth.enable = true;
  powerManagement.cpuFreqGovernor = "performance";

  sops = {
    defaultSopsFile = ../../secrets/dragon/secrets.yml;
    secrets =
      let
        danielSecret = {
          mode = "0400";
          owner = "daniel";
        };
        workstationSecret = danielSecret // {
          sopsFile = ../../secrets/workstations/secrets.yml;
        };
      in
      {
        ddns-pass.mode = "0400";
        nix-cache-priv-key.mode = "0400";
        claude-matrix-webhook = workstationSecret;
        claude-matrix-webhook-hive = workstationSecret;
        claude-matrix-webhook-code-review = workstationSecret;
        slack-user-token = danielSecret;
        notion-token = danielSecret;
        opencode-server-password = danielSecret;
      };
    templates."opencode-env" = {
      owner = "daniel";
      content = ''
        NOTION_TOKEN=${config.sops.placeholder.notion-token}
        OPENCODE_SERVER_PASSWORD=${config.sops.placeholder.opencode-server-password}
      '';
    };
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

  lyte = {
    editableConfigFiles = true;
    flakePath = "/etc/nix/flake";
    podman.enable = true;
    prevent-suspend.enable = true;
    headscale.usePreAuthKey = true;
    desktop.enable = true;
    gpu = "amd";
    # desktop.niri.enable = true; # temporarily disabled
    desktop.music-production = {
      enable = true;
      users = [ "daniel" ];
    };
    push-to-talk.enable = true;
    opencode = {
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
          app_dist = pkgs.stdenvNoCC.mkDerivation {
            name = "opencode-app-dist-dev";
            inherit src;
            nativeBuildInputs = [ pkgs.bun ];
            buildPhase = ''
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
    claude = {
      enable = true;
      sfxPath = "${config.users.users.daniel.home}/Documents/wc3sfx/peon/sounds";
      matrixWebhooks = {
        notify = config.sops.secrets.claude-matrix-webhook.path;
        hive = config.sops.secrets.claude-matrix-webhook-hive.path;
        code-review = config.sops.secrets.claude-matrix-webhook-code-review.path;
      };
    };
  };

  # these are just scripts and so do not cause bloated nixos installations
  environment.systemPackages = with pkgs; [
    opencode
    playwright-mcp
    mcpm-aider
    godot_4
  ];
}
