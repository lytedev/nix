{
  inputs,
  outputs,
  lib,
  # config,
  pkgs,
  ...
}: {
  networking.hostName = "thinker";

  imports = with outputs.nixosModules; [
    outputs.diskoConfigurations.thinker
    inputs.hardware.nixosModules.lenovo-thinkpad-t480
    inputs.hardware.nixosModules.common-pc-laptop-ssd
    desktop-usage
    podman
    # gnome
    kde-plasma
    postgres
    wifi
  ];

  environment = {
    systemPackages = with pkgs; [
      spotify
      discord
      slack
      godot_4
      fractal
      prismlauncher
      variety
      radeontop
      sops
      obs-studio
      xh
    ];
  };

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
  services.tlp = {
    enable = true;
  };
  services.power-profiles-daemon.enable = false;
  hardware.bluetooth.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  services.printing.enable = true; # I own a printer in the year of our Lord 2023

  home-manager.users.daniel = {
    imports = with outputs.homeManagerModules; [
      sway
      pass
      firefox-no-tabs
      # wallpaper-manager
      # sway-laptop
      # hyprland
    ];

    home = {
      stateVersion = "24.05";
    };

    services.mako.enable = lib.mkForce false; # don't use mako when using plasma
  };

  swapDevices = [
    # TODO: move this to disko?
    # sudo btrfs subvolume create /swap
    # sudo btrfs filesystem mkswapfile --size 32g --uuid clear /swap/swapfile
    # sudo swapon /swap/swapfile
    {device = "/swap/swapfile";}
  ];

  # findmnt -no UUID -T /swap/swapfile
  boot.resumeDevice = "/dev/disk/by-uuid/aacd6814-a5a2-457a-bf65-8d970cb1f03d";

  # services.logind = {
  #   lidSwitch = "suspend-then-hibernate";
  #   extraConfig = ''
  #     HandlePowerKey=suspend-then-hibernate
  #     IdleAction=suspend-then-hibernate
  #     IdleActionSec=10m
  #     HandleLidSwitchDocked=ignore
  #   '';
  # };
  # systemd.sleep.extraConfig = "HibernateDelaySec=30m";

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
