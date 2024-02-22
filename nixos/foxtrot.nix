{
  api-lyte-dev,
  inputs,
  outputs,
  pkgs,
  ...
}: let
  scale = 1.25;
in {
  networking.hostName = "foxtrot";

  imports = with outputs.nixosModules; [
    ({
      config,
      pkgs,
      ...
    }: let
      inherit (pkgs) lib;
      cfg = config.services.myservice;
    in {
      options.services.myservice = {
        enable = lib.mkEnableOption "Enables the api.lyte.dev service";
      };

      config =
        lib.mkIf cfg.enable {
        };
    })
    {
      services.myservice.enable = true;
    }

    outputs.diskoConfigurations.standard
    inputs.hardware.nixosModules.framework-13-7040-amd
    desktop-usage
    # gnome
    kde-plasma
    podman
    lutris
    # postgres
    wifi
    # hyprland
  ];

  services.xserver.enable = true;

  programs.steam.enable = true;
  programs.steam.remotePlay.openFirewall = true;

  environment = {
    systemPackages = with pkgs; [
      spotify
      discord
      slack
      godot_4
      fractal
      prismlauncher
      variety # wallpaper switcher that I use with GNOME
      radeontop
      sops
      obs-studio
    ];
  };

  home-manager.users.daniel = {
    imports = with outputs.homeManagerModules; [
      sway
      pass
      firefox-no-tabs
      wallpaper-manager
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

  services.upower.enable = true;

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
    # HandleLidSwitchDocked=ignore
    extraConfig = ''
      HandlePowerKey=suspend-then-hibernate
      IdleActionSec=10m
      IdleAction=suspend-then-hibernate
    '';
  };
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
