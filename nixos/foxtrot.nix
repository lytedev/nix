{
  # lib,
  inputs,
  outputs,
  pkgs,
  ...
}: let
  scale = 1.25;
in {
  networking.hostName = "foxtrot";

  imports = with outputs.nixosModules; [
    {
      nixpkgs.overlays = [
        outputs.overlays.modifications
      ];
    }
    outputs.diskoConfigurations.standard
    inputs.hardware.nixosModules.framework-13-7040-amd
    desktop-usage
    # gnome
    printing
    kde-plasma
    podman
    lutris
    # postgres
    wifi
    hyprland
    {
      programs.steam.enable = true;
      programs.steam.gamescopeSession.enable = true;
      # programs.steam.package = inputs.nixpkgs-stable.legacyPackages.${pkgs.system}.steam;
      programs.steam.remotePlay.openFirewall = true;
      services.udev.packages = with pkgs; [steam];
    }
    {
      # laptop power management
      services.upower.enable = true;
      swapDevices = [
        # TODO: move this to disko?
        # NOTE(oninstall):
        # sudo btrfs subvolume create /swap
        # sudo btrfs filesystem mkswapfile --size 32g --uuid clear /swap/swapfile
        # sudo swapon /swap/swapfile
        {device = "/swap/swapfile";}
      ];
      # findmnt -no UUID -T /swap/swapfile
      boot.resumeDevice = "/dev/disk/by-uuid/81c3354a-f629-4b6b-a249-7705aeb9f0d5";
      systemd.sleep.extraConfig = "HibernateDelaySec=30m";
      services.fwupd.enable = true;
      # source: https://github.com/NixOS/nixos-hardware/tree/master/framework/13-inch/7040-amd#getting-the-fingerprint-sensor-to-work
      # we need fwupd 1.9.7 to downgrade the fingerprint sensor firmware
      # services.fwupd.package =
      #   (import (builtins.fetchTarball {
      #       url = "https://github.com/NixOS/nixpkgs/archive/bb2009ca185d97813e75736c2b8d1d8bb81bde05.tar.gz";
      #       sha256 = "sha256:003qcrsq5g5lggfrpq31gcvj82lb065xvr7bpfa8ddsw8x4dnysk";
      #     }) {
      #       inherit (pkgs) system;
      #     })
      #   .fwupd;
      services.fwupd.extraRemotes = ["lvfs-testing"];
      services.logind = {
        lidSwitch = "suspend-then-hibernate";
        # HandleLidSwitchDocked=ignore
        extraConfig = ''
          HandlePowerKey=suspend-then-hibernate
          IdleActionSec=10m
          IdleAction=suspend-then-hibernate
        '';
      };
    }
  ];

  environment = {
    systemPackages = with pkgs; [
      steam
      spotify
      discord
      slack
      godot_4
      fractal
      prismlauncher
      upower
      acpi
      prismlauncher
      radeontop
      sops
      obs-studio
      xh
    ];
  };

  home-manager.users.daniel = {
    imports = with outputs.homeManagerModules; [
      sway
      pass
      firefox-no-tabs
      # wallpaper-manager
      hyprland
    ];
    home = {
      stateVersion = "24.05";
      pointerCursor = {
        size = 40;
      };
    };

    wayland.windowManager.hyprland = {
      settings = {
        env = [
          "EWW_BAR_MON,0"
        ];
        # See https://wiki.hyprland.org/Configuring/Keywords/ for more
        monitor = [
          "eDP-1,2256x1504@60,0x0,${toString scale}"
        ];
      };
    };

    wayland.windowManager.sway = {
      config = {
        output = {
          "BOE 0x0BCA Unknown" = {
            mode = "2256x1504@60Hz";
            position = "0,0";
            scale = toString scale;
          };

          "Dell Inc. DELL U2720Q D3TM623" = {
            # desktop left vertical monitor
            mode = "1920x1080@60Hz";
            # transform = "90";
            # scale = "1.5";
            position = "${toString (builtins.floor (2256 / scale))},0";
          };
        };
      };
    };
  };

  hardware.opengl.extraPackages = [
    # pkgs.rocmPackages.clr.icd
    pkgs.amdvlk

    # encoding/decoding acceleration
    pkgs.libvdpau-va-gl
    pkgs.vaapiVdpau
  ];

  networking.networkmanager.wifi.powersave = false;
  hardware.wirelessRegulatoryDatabase = true;

  hardware.framework.amd-7040.preventWakeOnAC = true;

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;

    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };

    # NOTE(oninstall):
    # sudo filefrag -v /swap/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}'
    # the above won't work for btrfs, instead you need
    # btrfs inspect-internal map-swapfile -r /swap/swapfile
    # https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Hibernation_into_swap_file
    # many of these come from https://wiki.archlinux.org/title/Framework_Laptop_13#Suspend
    kernelParams = [
      "rtc_cmos.use_acpi_alarm=1"
      "amdgpu.sg_display=0"
      "acpi_osi=\"!Windows 2020\""

      # "nvme.noacpi=1" # maybe causing crashes upon waking?

      # NOTE(oninstall):
      "resume_offset=3421665"
    ];
    initrd.availableKernelModules = ["xhci_pci" "nvme" "thunderbolt"];
    kernelModules = ["kvm-amd"];
    extraModprobeConfig = ''
      options cfg80211 ieee80211_regdom="US"
    '';
  };
  hardware.bluetooth = {
    enable = true;
    # TODO: when resuming from hibernation, it would be nice if this would
    # simply resume the power state at the time of hibernation
    powerOnBoot = false;
  };
  powerManagement.cpuFreqGovernor = "ondemand";

  services.power-profiles-daemon = {
    enable = true;
  };

  services.fprintd = {
    enable = true;
    package = pkgs.fprintd.overrideAttrs {
      # Source: https://github.com/NixOS/nixpkgs/commit/87ca2dc071581aea0e691c730d6844f1beb07c9f
      mesonCheckFlags = [
        # PAM related checks are timing out
        "--no-suite"
        "fprintd:TestPamFprintd"
      ];
    };
    # tod.enable = true;
    # tod.driver = pkgs.libfprint-2-tod1-goodix;
  };

  # services.tlp = {
  #   enable = true;
  #   settings = {
  #     CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
  #     CPU_SCALING_GOVERNOR_ON_BAT = "ondemand";
  #     CPU_MIN_PERF_ON_BAT = 0;
  #     CPU_MAX_PERF_ON_BAT = 80;

  #     CPU_SCALING_GOVERNOR_ON_AC = "performance";
  #     CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
  #     CPU_MIN_PERF_ON_AC = 0;
  #     CPU_MAX_PERF_ON_AC = 100;
  #   };
  # };

  networking.firewall.allowedTCPPorts = [
    8000 # dev stuff
  ];

  system.stateVersion = "24.05";
}
