{
  lib,
  inputs,
  outputs,
  modulesPath,
  ...
}: {
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "htpc";

  imports = with outputs.nixosModules; [
    (modulesPath + "/installer/scan/not-detected.nix")
    inputs.hardware.nixosModules.common-cpu-intel-kaby-lake
    inputs.hardware.nixosModules.common-pc-ssd
    inputs.hardware.nixosModules.common-pc
    desktop-usage
    gnome
    wifi
    flanfam
    flanfamkiosk
  ];

  networking.networkmanager.enable = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  home-manager.users.daniel = {
    imports = with outputs.homeManagerModules; [linux-desktop];
  };

  environment.systemPackages =
    #with pkgs;
    [];

  programs.steam.enable = true;
  programs.steam.remotePlay.openFirewall = true;

  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "daniel";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # hardware
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  powerManagement.enable = false;

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "sdhci_pci"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/0f4e5814-0002-43f0-bfab-8368e3fe5b8a";
    fsType = "ext4";
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  system.stateVersion = "23.11";
}
