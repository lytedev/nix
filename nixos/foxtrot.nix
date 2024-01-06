{
  flake,
  inputs,
  outputs,
  lib,
  # config,
  pkgs,
  ...
}: let
  scale = 1.25;
in {
  networking.hostName = "foxtrot";

  imports =
    [
      flake.diskoConfigurations.standard
      inputs.hardware.nixosModules.framework-13-7040-amd
    ]
    ++ (with outputs.nixosModules; [
      desktop-usage
      podman
      postgres
      wifi
      # hyprland
    ]);

  programs.steam.enable = true;
  programs.steam.remotePlay.openFirewall = true;

  home-manager.users.daniel = {
    imports = with outputs.homeManagerModules; [
      sway
      pass
      # sway-laptop
      # hyprland
    ];

    home = {
      stateVersion = "24.05";
    };

    wayland.windowManager.hyprland = {
      settings = {
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
            scale = toString scale;
          };
        };
      };
    };
  };

  # use updated ppd for framework 13:
  # source: https://community.frame.work/t/tracking-ppd-v-tlp-for-amd-ryzen-7040/39423/137?u=lytedev
  nixpkgs.overlays = [
    (
      final: prev: {
        power-profiles-daemon = prev.power-profiles-daemon.overrideAttrs (
          old: {
            version = "0.13-1";

            patches =
              (old.patches or [])
              ++ [
                (prev.fetchpatch {
                  url = "https://gitlab.freedesktop.org/upower/power-profiles-daemon/-/merge_requests/127.patch";
                  sha256 = "sha256-jnq5yJvWQHOlZ78SE/4/HqiQfF25YHQH/T4wwDVRHR0=";
                })
                (prev.fetchpatch {
                  url = "https://gitlab.freedesktop.org/upower/power-profiles-daemon/-/merge_requests/128.patch";
                  sha256 = "sha256-YD9wn9IQlCp02r4lmwRnx9Eur2VVP1JfC/Bm8hlzF3Q=";
                })
                (prev.fetchpatch {
                  url = "https://gitlab.freedesktop.org/upower/power-profiles-daemon/-/merge_requests/129.patch";
                  sha256 = "sha256-9T+I3BAUW3u4LldF85ctE0/PLu9u+KBN4maoL653WJU=";
                })
              ];

            # explicitly fetching the source to make sure we're patching over 0.13 (this isn't strictly needed):
            src = prev.fetchFromGitLab {
              domain = "gitlab.freedesktop.org";
              owner = "hadess";
              repo = "power-profiles-daemon";
              rev = "0.13";
              sha256 = "sha256-ErHy+shxZQ/aCryGhovmJ6KmAMt9OZeQGDbHIkC0vUE=";
            };
          }
        );
      }
    )
  ];

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
      "amdgpu.sg_display=0"
      "acpi_osi=\"!Windows 2020\""
      # NOTE(oninstall):
      "resume_offset=3421665"
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
    # TODO: when resuming from hibernation, it would be nice if this would
    # simply resume the power state at the time of hibernation
    powerOnBoot = false;
  };
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  services.power-profiles-daemon = {
    enable = true;
  };
  powerManagement.powertop.enable = true;

  # disabled stuff here for posterity
  services.fprintd = {
    enable = false;
    # tod.enable = true;
    # tod.driver = pkgs.libfprint-2-tod1-goodix;
  };
  services.tlp = {
    enable = false;
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

  system.stateVersion = "24.05";
}
