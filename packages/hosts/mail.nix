{
  config,
  lib,
  ...
}:
{
  system.stateVersion = "25.11";
  networking.hostName = "mail";

  # Hetzner VPS: 2 vCPU Intel Xeon, 4GB RAM, 38G disk
  # BIOS boot (no UEFI)
  diskConfig = {
    name = "unencrypted-bios";
    params = {
      disk = "/dev/sda";
    };
  };

  # GRUB for BIOS boot — disko auto-adds /dev/sda via the EF02 partition
  boot.loader.grub.enable = true;

  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
  ];

  networking = {
    useDHCP = true;
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [
        22
        25 # SMTP inbound
      ];
    };
  };

  services.tailscale = {
    useRoutingFeatures = "server";
    extraUpFlags = [
      "--accept-routes"
    ];
  };

  lyte.headscale.usePreAuthKey = true;
  lyte.shell.enable = false;
  lyte.prevent-suspend.enable = true;

  # Disable services not needed on a minimal VPS
  services.avahi.enable = false;
  services.smartd.enable = false;
}
