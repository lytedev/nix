{
  flake,
  inputs,
  outputs,
  # lib,
  # config,
  # pkgs,
  ...
}: {
  networking.hostName = "musicbox";

  imports =
    [
      inputs.disko.nixosModules.disko
      flake.diskoConfigurations.unencrypted
    ]
    ++ (with outputs.nixosModules; [
      desktop-usage
      wifi
    ]);

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  hardware.bluetooth.enable = true;
  networking.networkmanager.enable = true;

  system.stateVersion = "23.05";
}
