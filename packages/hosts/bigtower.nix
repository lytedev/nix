{
  hardware,
  config,
  ...
}:
{
  system.stateVersion = "24.05";
  networking = {
    hostName = "bigtower";
    wifi.enable = true;
  };

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
    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.enable = true;
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "ahci"
      "usbhid"
    ];
    kernelModules = [ "kvm-amd" ];
    supportedFilesystems = [ "ntfs" ];
  };

  imports = with hardware; [
    common-cpu-amd
    common-gpu-amd
    common-pc-ssd
  ];

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

  programs.steam.enable = true;
  lyte.desktop.enable = true;

  home-manager.users.daniel = {
    lyte.shell.enable = true;
    lyte.desktop.enable = true;
    slippi-launcher = {
      enable = true;
      isoPath = "${config.users.users.daniel.home}/../games/roms/dolphin/melee.iso";
      launchMeleeOnPlay = false;
    };
  };
}
