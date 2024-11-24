{pkgs, ...}:
/*
## source: https://community.frame.work/t/speakers-sound-quality/1078/82
let
  pipewire-speakers-profile-json = ''{
    "output": {
        "blocklist": [],
        "equalizer": {
            "balance": 0.0,
            "bypass": false,
            "input-gain": 0.0,
            "left": {
                "band0": {
                    "frequency": 100.0,
                    "gain": 0.0,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 1.0,
                    "slope": "x4",
                    "solo": false,
                    "type": "Hi-pass"
                },
                "band1": {
                    "frequency": 150.0,
                    "gain": 4.02,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 3.0,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band2": {
                    "frequency": 600.0,
                    "gain": -5.07,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 4.000000000000008,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band3": {
                    "frequency": 1200.0,
                    "gain": -3.49,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 4.17,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band4": {
                    "frequency": 2000.0,
                    "gain": 1.43,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 4.0,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band5": {
                    "frequency": 5300.0,
                    "gain": 3.84,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 2.64,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band6": {
                    "frequency": 6000.0,
                    "gain": 4.02,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 4.36,
                    "slope": "x1",
                    "solo": false,
                    "type": "Hi-shelf"
                },
                "band7": {
                    "frequency": 7500.0,
                    "gain": -2.09,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 3.0,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band8": {
                    "frequency": 8000.0,
                    "gain": 2.01,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 4.36,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band9": {
                    "frequency": 900.0,
                    "gain": -4.12,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 5.909999999999967,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                }
            },
            "mode": "IIR",
            "num-bands": 10,
            "output-gain": -1.5,
            "pitch-left": 0.0,
            "pitch-right": 0.0,
            "right": {
                "band0": {
                    "frequency": 100.0,
                    "gain": 0.0,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 1.0,
                    "slope": "x4",
                    "solo": false,
                    "type": "Hi-pass"
                },
                "band1": {
                    "frequency": 150.0,
                    "gain": 4.02,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 3.0,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band2": {
                    "frequency": 600.0,
                    "gain": -5.07,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 4.000000000000008,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band3": {
                    "frequency": 1200.0,
                    "gain": -3.49,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 4.17,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band4": {
                    "frequency": 2000.0,
                    "gain": 1.43,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 4.0,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band5": {
                    "frequency": 5300.0,
                    "gain": 3.84,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 2.64,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band6": {
                    "frequency": 6000.0,
                    "gain": 4.02,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 4.36,
                    "slope": "x1",
                    "solo": false,
                    "type": "Hi-shelf"
                },
                "band7": {
                    "frequency": 7500.0,
                    "gain": -2.09,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 3.0,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band8": {
                    "frequency": 8000.0,
                    "gain": 2.01,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 4.36,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                },
                "band9": {
                    "frequency": 900.0,
                    "gain": -4.12,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 5.909999999999967,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell"
                }
            },
            "split-channels": false
        },
        "loudness": {
            "bypass": false,
            "clipping": false,
            "clipping-range": 6.0,
            "fft": "4096",
            "input-gain": 0.0,
            "output-gain": 0.0,
            "std": "ISO226-2003",
            "volume": 6.999999999999991
        },
        "plugins_order": [
            "loudness",
            "equalizer"
        ]
    }
}'';
in
*/
{
  imports = [
    {
      system.stateVersion = "24.05";
      home-manager.users.daniel.home.stateVersion = "24.05";
      networking.hostName = "foxtrot";
    }
    {
      swapDevices = [
        # TODO: move this to disko?
        # NOTE(oninstall):
        /*
        sudo btrfs subvolume create /swap
        sudo btrfs filesystem mkswapfile --size 32g --uuid clear /swap/swapfile
        sudo swapon /swap/swapfile
        */
        {device = "/swap/swapfile";}
      ];
      # findmnt -no UUID -T /swap/swapfile
      boot.resumeDevice = "/dev/disk/by-uuid/81c3354a-f629-4b6b-a249-7705aeb9f0d5";
      # systemd.sleep.extraConfig = "HibernateDelaySec=180m";
      services.fwupd.enable = true;
      services.fwupd.extraRemotes = ["lvfs-testing"];
    }
  ];

  environment = {
    systemPackages = with pkgs; [
      godot_4
      fractal
      prismlauncher
      upower
      acpi
      prismlauncher
      radeontop
      sops
      xh
    ];
  };

  home-manager.users.daniel = {
    home = {
      pointerCursor = {
        size = 40;
      };
    };

    /*
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
    */

    wayland.windowManager.sway = {
      config = {
        output = {
          "BOE NE135A1M-NY1 Unknown" = {
            mode = "2880x1920@120Hz";
            position = "1092,2160";
            scale = toString 1.75;
          };

          "Dell Inc. DELL U2720Q CWTM623" = {
            mode = "3840x2160@60Hz";
            position = "0,0";
            scale = toString 1.25;
          };

          /*
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
          */
        };
      };
    };
  };

  hardware.graphics.extraPackages = [
    # pkgs.rocmPackages.clr.icd
    pkgs.amdvlk

    # encoding/decoding acceleration
    pkgs.libvdpau-va-gl
    pkgs.vaapiVdpau
  ];

  networking.networkmanager.wifi.powersave = false;

  hardware.framework.amd-7040.preventWakeOnAC = true;

  boot = {
    # kernelPackages = pkgs.linuxPackages_latest;

    # https://github.com/void-linux/void-packages/issues/50417#issuecomment-2131802836 fix framework 13 not shutting down
    /*
    kernelPatches = [
      {
        name = "framework13shutdownfix";
        patch = builtins.fetchurl {
          url = "https://github.com/void-linux/void-packages/files/15445612/0001-Add-hopefully-a-solution-for-shutdown-regression.PATCH";
          sha256 = "sha256:10zcnzy5hkam2cnxx441b978gzhvnqlcc49k7bpz9dc28xyjik50";
        };
      }
    ];
    */

    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };

    # NOTE(oninstall):
    /*
    sudo filefrag -v /swap/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}'
    the above won't work for btrfs, instead you need btrfs inspect-internal map-swapfile -r /swap/swapfile
    https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Hibernation_into_swap_file
    many of these come from https://wiki.archlinux.org/title/Framework_Laptop_13#Suspend
    */
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
  };
  hardware.bluetooth = {
    enable = true;
    # TODO: when resuming from hibernation, it would be nice if this would
    # simply resume the power state at the time of hibernation
    powerOnBoot = false;

    package = pkgs.bluez.overrideAttrs (finalAttrs: previousAttrs: rec {
      version = "5.78";
      src = pkgs.fetchurl {
        url = "mirror://kernel/linux/bluetooth/bluez-${version}.tar.xz";
        sha256 = "sha256-gw/tGRXF03W43g9eb0X83qDcxf9f+z0x227Q8A1zxeM=";
      };
      patches = [];
      buildInputs =
        previousAttrs.buildInputs
        ++ [
          pkgs.python3Packages.pygments
        ];
    });
  };
  powerManagement.cpuFreqGovernor = "ondemand";
  /*
  powerManagement.resumeCommands = ''
    modprobe -rv mt7921e
    modprobe -v mt7921e
  '';
  */

  services.power-profiles-daemon = {
    enable = true;
  };

  services.fprintd = {
    enable = false;
    package = pkgs.fprintd.overrideAttrs {
      # Source: https://github.com/NixOS/nixpkgs/commit/87ca2dc071581aea0e691c730d6844f1beb07c9f
      mesonCheckFlags = [
        # PAM related checks are timing out
        "--no-suite"
        "fprintd:TestPamFprintd"
      ];
    };
  };

  /*
  services.tlp = {
    enable = true;
    settings = {
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_SCALING_GOVERNOR_ON_BAT = "ondemand";
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 80;

      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
    };
  };
  */

  networking.firewall.allowedTCPPorts = let
    stardewValley = 24642;
    factorio = 34197;
  in [
    8000 # dev stuff
    factorio
    stardewValley
    7777
  ];
  networking.firewall.allowedUDPPorts = let
    stardewValley = 24642;
    factorio = 34197;
  in [
    8000 # dev stuff
    factorio
    stardewValley
    7777
  ];
}
