{
  outputs,
  # lib,
  # config,
  # pkgs,
  ...
}: {
  networking.hostName = "musicbox";

  imports = with outputs.nixosModules; [
    outputs.diskoConfigurations.unencrypted
    desktop-usage
    wifi
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  hardware.bluetooth.enable = true;
  networking.networkmanager.enable = true;

  system.stateVersion = "23.05";
}
