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

  swapDevices = [
    # TODO: move this to disko?
    # sudo btrfs subvolume create /swap
    # sudo btrfs filesystem mkswapfile --size 32g --uuid clear /swap/swapfile
    # sudo swapon /swap/swapfile
    {device = "/swap/swapfile";}
  ];

  # findmnt -no UUID -T /swap/swapfile
  boot.resumeDevice = "/dev/disk/by-uuid/aacd6814-a5a2-457a-bf65-8d970cb1f03d";

  services.logind = {
    lidSwitch = "suspend-then-hibernate";
    extraConfig = ''
      HandlePowerKey=suspend-then-hibernate
      IdleAction=suspend-then-hibernate
      IdleActionSec=10m
    '';
  };
  systemd.sleep.extraConfig = "HibernateDelaySec=30m";

  imports =
    [
      inputs.disko.nixosModules.disko
      flake.diskoConfigurations.thinker
    ]
    ++ (with outputs.nixosModules; [
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

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    # sudo filefrag -v /swap/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}'
    # the above won't work for btrfs, instead you need
    # btrfs inspect-internal map-swapfile -r /swap/swapfile
    # https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Hibernation_into_swap_file
    kernelParams = ["boot.shell_on_fail" "resume_offset=22816000"];
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

  # networking.networkmanager.enable = false;
  # systemd.services.NetworkManager-wait-online.enable = lib.mkDefault false;
  # networking.wireless.iwd.enable = true;

  system.stateVersion = "23.11";
}
