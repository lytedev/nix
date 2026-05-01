{
  config,
  ...
}:
{
  system.stateVersion = "25.11";
  networking.hostName = "flab";
  diskConfig = "babyflip";
  hardwareModules = [
    "framework-12-13th-gen-intel"
    "common-cpu-intel"
    "common-pc-ssd"
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
  ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.kernelParams = [ "mem_sleep_default=deep" ];

  hardware.bluetooth.powerOnBoot = true;

  lyte = {
    editableConfigFiles = true;
    flakePath = "/etc/nix/flake";
    podman.enable = true;
    two-in-one.enable = true;
    gpu = "intel";
    family-account.enable = true;
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

  services.syncthing = {
    cert = config.sops.secrets.syncthing-cert.path;
    key = config.sops.secrets.syncthing-key.path;
  };

  sops = {
    secrets.claude-matrix-webhook = {
      sopsFile = ../../secrets/workstations/secrets.yml;
      mode = "0400";
      owner = "daniel";
      group = "users";
    };
    secrets.claude-matrix-webhook-hive = {
      sopsFile = ../../secrets/workstations/secrets.yml;
      mode = "0400";
      owner = "daniel";
      group = "users";
    };
    secrets.claude-matrix-webhook-code-review = {
      sopsFile = ../../secrets/workstations/secrets.yml;
      mode = "0400";
      owner = "daniel";
      group = "users";
    };
    secrets.syncthing-key = {
      sopsFile = ../../secrets/flab/secrets.yml;
      mode = "0400";
      owner = "daniel";
      group = "users";
    };
    secrets.syncthing-cert = {
      sopsFile = ../../secrets/flab/secrets.yml;
      mode = "0400";
      owner = "daniel";
      group = "users";
    };
  };

}
