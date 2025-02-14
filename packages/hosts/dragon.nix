{
  pkgs,
  lib,
  config,
  hardware,
  diskoConfigurations,
  ...
}: {
  system.stateVersion = "24.11";
  home-manager.users.daniel.home.stateVersion = "24.11";
  networking.hostName = "dragon";

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.enable = true;
    initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci" "usbhid"];
    kernelModules = ["kvm-amd"];
    supportedFilesystems = ["ntfs"];
  };

  imports = with hardware; [
    (diskoConfigurations.unencrypted {disk = "/dev/nvme0n1";})
    common-cpu-amd
    common-gpu-amd
    common-pc-ssd
  ];

  sops.secrets.ddns-pass = {mode = "0400";};
  services.deno-netlify-ddns-client = {
    passwordFile = config.sops.secrets.ddns-pass.path;
    enable = true;
    username = "dragon.h";
    # TODO: router doesn't even do ipv6 yet...
    ipv6 = false;
  };

  hardware.bluetooth.enable = true;
  networking.wifi.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  home-manager.users.daniel = {
    slippi-launcher = {
      enable = true;
      isoPath = "${config.home-manager.users.daniel.home.homeDirectory}/../games/roms/dolphin/melee.iso";
      launchMeleeOnPlay = false;
    };
  };
}
