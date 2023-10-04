{
  flake,
  inputs,
  outputs,
  lib,
  # config,
  # pkgs,
  ...
}: {
  networking.hostName = "thinker";

  imports =
    [
      inputs.disko.nixosModules.disko
      flake.diskoConfigurations.thinker
    ]
    ++ (with outputs.nixosModules; [
      # If you want to use modules your own flake exports (from modules/nixos):
      desktop-usage
      podman
      postgres
      wifi
    ])
    ++ [
      inputs.hardware.nixosModules.lenovo-thinkpad-t480
      inputs.hardware.nixosModules.common-pc-laptop-ssd
      # ./relative-module.nix
    ];

  # TODO: hibernation? I've been using [deep] in /sys/power/mem_sleep alright
  # with this machine so it may not be necessary?
  # need to measure percentage lost per day, but I think it's around 10%/day
  # it looks like I may have had hibernation working -- see ../old/third.nix

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    kernelParams = ["boot.shell_on_fail"];
    initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci"];
  };
  hardware.bluetooth.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  services.printing.enable = true; # I own a printer in the year of our Lord 2023

  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [22];
      allowedUDPPorts = [];
    };
  };

  system.stateVersion = "23.11";
}
