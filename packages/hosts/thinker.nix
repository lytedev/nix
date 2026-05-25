{ config, ... }:
{
  system.stateVersion = "24.11";
  networking.hostName = "thinker";
  diskConfig = "thinker";
  hardwareModules = [
    "lenovo-thinkpad-t480"
    "common-pc-laptop-ssd"
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "ahci"
  ];

  # Required so claude code (and other dynamically-linked node binaries
  # under npm/asdf/etc.) can find a glibc loader at runtime.
  programs.nix-ld.enable = true;

  sops.secrets =
    let
      workstationSecret = {
        sopsFile = ../../secrets/workstations/secrets.yml;
        mode = "0400";
        owner = "daniel";
        group = "users";
      };
    in
    {
      claude-matrix-webhook = workstationSecret;
      claude-matrix-webhook-hive = workstationSecret;
      claude-matrix-webhook-code-review = workstationSecret;
    };

  lyte = {
    editableConfigFiles = true;
    flakePath = "/etc/nix/flake";
    laptop.enable = true;
    claude = {
      enable = true;
      matrixWebhooks = {
        notify = config.sops.secrets.claude-matrix-webhook.path;
        hive = config.sops.secrets.claude-matrix-webhook-hive.path;
        code-review = config.sops.secrets.claude-matrix-webhook-code-review.path;
      };
    };
  };
}
