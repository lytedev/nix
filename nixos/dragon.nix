{
  flake,
  inputs,
  outputs,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  networking.hostName = "dragon";

  # support interacting with the windows drive
  boot.supportedFilesystems = ["ntfs"];

  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      inputs.disko.nixosModules.disko
      flake.diskoConfigurations.standard
      inputs.hardware.nixosModules.common-cpu-amd
      inputs.hardware.nixosModules.common-pc-ssd
      outputs.nixosModules.pipewire-low-latency
    ]
    ++ (with outputs.nixosModules; [
      common
      melee
      desktop-usage
      podman
      postgres
      wifi
      hyprland
      printing
      ewwbar
    ]);

  services.printing.enable = true;

  # TODO: https://nixos.wiki/wiki/Remote_LUKS_Unlocking

  # hardware
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;
  boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci"];
  boot.kernelModules = ["kvm-amd"];

  hardware.bluetooth.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  environment = {
    systemPackages = with pkgs; [
      radeontop
    ];
  };

  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [22 7777];
      allowedUDPPorts = [];
    };
  };

  services.udev.packages = [
    pkgs.platformio
    pkgs.openocd
  ];
  programs.adb.enable = true;
  users.users.daniel.extraGroups = ["adbusers"];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}
