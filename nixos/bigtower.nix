{
  pkgs,
  lib,
  config,
  ...
}: {
  system.stateVersion = "24.05";
  home-manager.users.daniel.home.stateVersion = "24.05";
  networking.hostName = "bigtower";
  networking.useDHCP = true;

  imports = [
    {
      fileSystems."/" = {
        device = "/dev/disk/by-uuid/5b6c2d65-2704-4ed1-b06d-5ee7110b3d28";
        fsType = "btrfs";
        options = ["subvol=root"];
      };
      fileSystems."/nix" = {
        device = "/dev/disk/by-uuid/5b6c2d65-2704-4ed1-b06d-5ee7110b3d28";
        fsType = "btrfs";
        options = ["subvol=nix"];
      };
      fileSystems."/home" = {
        device = "/dev/disk/by-uuid/5b6c2d65-2704-4ed1-b06d-5ee7110b3d28";
        fsType = "btrfs";
        options = ["subvol=home"];
      };
      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/CE80-4623";
        fsType = "vfat";
        options = ["fmask=0022" "dmask=0022"];
      };
    }
  ];
  hardware.graphics.extraPackages = [
    pkgs.amdvlk
    pkgs.libvdpau-va-gl
    pkgs.vaapiVdpau
  ];

  boot = {
    # kernelPackages = pkgs.linuxPackages_zen;
    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.enable = true;
    initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci" "usbhid"];
    kernelModules = ["kvm-amd"];
    supportedFilesystems = ["ntfs"];
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
}
