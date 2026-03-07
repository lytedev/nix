{
  hardware,
  config,
  pkgs,
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
    common-pc-ssd
  ];

  prevent-suspend.enable = true;

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
    secrets.nix-cache-priv-key.mode = "0400";
  };

  services.harmonia = {
    enable = true;
    signKeyPaths = [ config.sops.secrets.nix-cache-priv-key.path ];
  };

  networking.firewall.allowedTCPPorts = [ 5000 ];

  # TODO: temporary: https://github.com/nix-community/home-manager/issues/3113#issuecomment-3368651274
  programs.dconf.enable = true;

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  programs.steam.enable = true;

  lyte = {
    desktop.enable = true;
    gpu = "amd";
  };
}
