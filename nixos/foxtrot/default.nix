{
  flake,
  inputs,
  outputs,
  lib,
  # config,
  pkgs,
  ...
}: {
  networking.hostName = "foxtrot";

  imports =
    [
      inputs.disko.nixosModules.disko
      flake.diskoConfigurations.standard
    ]
    ++ (with outputs.nixosModules; [
      desktop-usage
      podman
      postgres
      wifi
    ])
    ++ [
      inputs.hardware.nixosModules.framework-13-7040-amd
    ];

  swapDevices = [
    # TODO: move this to disko?
    # sudo btrfs subvolume create /swap
    # sudo btrfs filesystem mkswapfile --size 32g --uuid clear /swap/swapfile
    # sudo swapon /swap/swapfile
    {device = "/swap/swapfile";}
  ];

  # findmnt -no UUID -T /swap/swapfile
  boot.resumeDevice = "/dev/disk/by-uuid/3076912c-ac61-4067-b6b2-361f68b2d038";

  services.logind = {
    lidSwitch = "suspend-then-hibernate";
    extraConfig = ''
      HandlePowerKey=suspend-then-hibernate
      IdleAction=suspend-then-hibernate
      IdleActionSec=10m
    '';
  };
  systemd.sleep.extraConfig = "HibernateDelaySec=90m";

  services.fwupd.enable = true;
  services.fwupd.extraRemotes = ["lvfs-testing"];

  hardware.opengl.extraPackages = [
    # pkgs.rocmPackages.clr.icd
    pkgs.amdvlk
    # encoding/decoding acceleration
    pkgs.libvdpau-va-gl
    pkgs.vaapiVdpau
  ];

  hardware.wirelessRegulatoryDatabase = true;

  boot = {
    kernelPackages = pkgs.linuxPackages_latest; # seeing if using the stable kernel makes wow work

    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };

    # sudo filefrag -v /swap/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}'
    # the above won't work for btrfs, instead you need
    # btrfs inspect-internal map-swapfile -r /swap/swapfile
    # https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Hibernation_into_swap_file
    # many of these come from https://wiki.archlinux.org/title/Framework_Laptop_13#Suspend
    kernelParams = [
      "amdgpu.sg_display=0"
      "acpi_osi=\"!Windows 2020\""
      "resume_offset=39331072"
      # "nvme.noacpi=1" # maybe causing crashes upon waking?
      "rtc_cmos.use_acpi_alarm=1"
    ];
    initrd.availableKernelModules = ["xhci_pci" "nvme" "thunderbolt"];
    kernelModules = ["kvm-amd"];
    extraModprobeConfig = ''
      options cfg80211 ieee80211_regdom="US"
    '';
  };
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
  services.printing.enable = true;
  services.fprintd = {
    enable = false;
    # tod.enable = true;
    # tod.driver = pkgs.libfprint-2-tod1-goodix;
  };
  services.power-profiles-daemon = {
    enable = false;
  };
  services.tlp = {
    enable = true;
    settings = {
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_SCALING_GOVERNOR_ON_BAT = "ondemand";
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 60;

      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
    };
  };
  powerManagement.powertop.enable = true;

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
