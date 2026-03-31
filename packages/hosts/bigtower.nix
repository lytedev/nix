{
  config,
  pkgs,
  lib,
  ...
}:
{
  system.stateVersion = "24.05";
  networking = {
    hostName = "bigtower";
    wifi.enable = true;
  };

  hardwareModules = [
    "common-cpu-amd"
    "common-pc-ssd"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/5b6c2d65-2704-4ed1-b06d-5ee7110b3d28";
    fsType = "btrfs";
    options = [ "subvol=root" ];
  };
  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/5b6c2d65-2704-4ed1-b06d-5ee7110b3d28";
    fsType = "btrfs";
    options = [ "subvol=nix" ];
  };
  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/5b6c2d65-2704-4ed1-b06d-5ee7110b3d28";
    fsType = "btrfs";
    options = [ "subvol=home" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/CE80-4623";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  boot = {
    # kernelPackages = pkgs.linuxPackages_zen;
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "ahci"
      "usbhid"
    ];
    kernelModules = [ "kvm-amd" ];
    supportedFilesystems = [ "ntfs" ];
  };

  hardware.bluetooth = {
    enable = true;
    # package = pkgs.bluez;
    settings = {
      General = {
        AutoConnect = true;
        MultiProfile = "multiple";
      };
    };
  };
  powerManagement.cpuFreqGovernor = "performance";

  environment.systemPackages = with pkgs; [
    lutris
  ];

  sops = {
    defaultSopsFile = ../../secrets/bigtower/secrets.yml;
    secrets = {
      nix-cache-priv-key.mode = "0400";
      "forgejo-runner.env".mode = "0400";
    };
  };

  services = {
    harmonia = {
      enable = true;
      signKeyPaths = [ config.sops.secrets.nix-cache-priv-key.path ];
    };
    sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
      openFirewall = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 5000 ];

  # TODO: temporary: https://github.com/nix-community/home-manager/issues/3113#issuecomment-3368651274
  programs.dconf.enable = true;

  programs.steam.enable = true;

  # --- Forgejo runners for agent tasks ---
  services.gitea-actions-runner = {
    instances =
      let
        runnerCount = 2;
      in
      lib.genAttrs (builtins.genList (n: "bigtower${builtins.toString n}") runnerCount) (name: {
        enable = true;
        name = "bigtower";
        url = "https://git.lyte.dev";
        settings.container.network = "host";
        labels = [
          "bigtower:host"
          "agent:host"
        ];
        tokenFile = config.sops.secrets."forgejo-runner.env".path;
        hostPackages = with pkgs; [
          config.nix.package
          bash
          coreutils
          curl
          gawk
          gitMinimal
          gnused
          nodejs
          gnutar
          wget
        ];
      });
  };

  systemd.services =
    lib.genAttrs (builtins.genList (n: "gitea-runner-bigtower${builtins.toString n}") 2)
      (name: {
        after = [ "sops-nix.service" ];
      });

  lyte = {
    server.enable = true;
    server.logs.enable = false;
    headscale.usePreAuthKey = true;
    desktop.enable = true;
    gpu = "amd";
  };
}
