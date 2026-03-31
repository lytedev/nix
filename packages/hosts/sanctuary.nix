{
  config,
  pkgs,
  lib,
  ...
}:
{
  system.stateVersion = "24.11";
  networking.hostName = "sanctuary-av";

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
  };

  powerManagement.cpuFreqGovernor = "performance";

  hardware.bluetooth = {
    enable = true;
    settings = {
      General = {
        AutoConnect = true;
        MultiProfile = "multiple";
      };
    };
  };

  # TODO: monitor mirroring
  # TODO: plasma or gnome dock?
  # TODO: lyricscreen service
  # TODO: audio management and recoring? is audacity sufficient? do we need drivers for the USB connection to the soundboard?
  # TODO: nixos tests?

  networking.wifi.enable = true;

  # --- Forgejo runners for agent tasks ---
  sops = {
    defaultSopsFile = ../../secrets/sanctuary/secrets.yml;
    secrets."forgejo-runner.env".mode = "0400";
  };

  services.gitea-actions-runner = {
    instances =
      let
        runnerCount = 2;
      in
      lib.genAttrs (builtins.genList (n: "sanctuary${builtins.toString n}") runnerCount) (name: {
        enable = true;
        name = "sanctuary";
        url = "https://git.lyte.dev";
        settings.container.network = "host";
        labels = [
          "sanctuary:host"
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
    lib.genAttrs (builtins.genList (n: "gitea-runner-sanctuary${builtins.toString n}") 2)
      (name: {
        after = [ "sops-nix.service" ];
      });

  lyte = {
    server.enable = true;
    server.logs.enable = false;
    headscale.usePreAuthKey = true;
    desktop.enable = true;
    gpu = "amd";
    family-account.enable = true;
  };
}
