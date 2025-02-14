{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    {
      system.stateVersion = "24.11";
      home-manager.users.daniel.home.stateVersion = "24.05";
      networking.hostName = "dragon";
    }

    {
      # sops secrets config
      sops = {
        defaultSopsFile = ../secrets/dragon/secrets.yml;
        age = {
          sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
          keyFile = "/var/lib/sops-nix/key.txt";
          generateKey = true;
        };
      };
    }
    {
      sops.secrets = {
        ddns-pass = {mode = "0400";};
      };
      services.deno-netlify-ddns-client = {
        passwordFile = config.sops.secrets.ddns-pass.path;
      };
    }
  ];
  hardware.amdgpu = {
    amdvlk = {
      enable = true;
      support32Bit = {
        enable = true;
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

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.enable = true;
    initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci" "usbhid"];
    kernelModules = ["kvm-amd"];
    supportedFilesystems = ["ntfs"];
  };

  hardware.bluetooth = {
    enable = true;
    # package = pkgs.bluez;
    settings = {
      General = {
        AutoConnect = true;
        MultiProfile = "multiple";
      };
    };
  };
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  # dragon firewall
  # TODO: maybe should go in the gaming module?
  networking = {
    firewall = let
      terraria = 7777;
      stardew-valley = 24642;
      web-dev-lan = 18888;
      ports = [
        terraria
        stardew-valley
        web-dev-lan
      ];
    in {
      allowedTCPPorts = ports;
      allowedUDPPorts = ports;
    };
  };

  environment.systemPackages = with pkgs; [
    radeontop
    godot_4
    prismlauncher
  ];

  home-manager.users.daniel = {
    slippi-launcher = {
      enable = true;
      isoPath = "${config.home-manager.users.daniel.home.homeDirectory}/../games/roms/dolphin/melee.iso";
      launchMeleeOnPlay = false;
    };

    # TODO: monitor config module?
    wayland.windowManager.hyprland = {
      settings = {
        exec-once = [
          "eww open bar1"
        ];
        # See https://wiki.hyprland.org/Configuring/Keywords/ for more
        monitor = [
          # "DP-2,3840x2160@60,-2160x0,1,transform,3"
          # "DP-3,3840x2160@120,${toString (builtins.ceil (2160 / 1.5))}x0,1"
          "DP-3,3840x2160@120,0x0,1"
          # TODO: HDR breaks screenshare?
          /*
          "DP-3,3840x2160@120,${toString (builtins.ceil (2160 / 1.5))}x0,1,bitdepth,10"
          "desc:LG Display 0x0521,3840x2160@120,0x0,1"
          "desc:Dell Inc. DELL U2720Q D3TM623,3840x2160@60,3840x0,1.5,transform,1"
          */
          "DP-2,3840x2160@60,3840x0,1.5,transform,3"
        ];
        input = {
          force_no_accel = true;
          sensitivity = 1; # -1.0 - 1.0, 0 means no modification.
        };
        workspace = [
          "1, monitor:DP-3, default:true"
          "2, monitor:DP-3, default:false"
          "3, monitor:DP-3, default:false"
          "4, monitor:DP-3, default:false"
          "5, monitor:DP-3, default:false"
          "6, monitor:DP-3, default:false"
          "7, monitor:DP-3, default:false"
          "8, monitor:DP-2, default:true"
          "9, monitor:DP-2, default:false"
        ];
      };
    };

    wayland.windowManager.sway = {
      config = {
        output = {
          "GIGA-BYTE TECHNOLOGY CO., LTD. AORUS FO48U 23070B000307" = {
            mode = "3840x2160@120Hz";
            position = "${toString (builtins.ceil (2160 / 1.5))},0";
          };

          "Dell Inc. DELL U2720Q D3TM623" = {
            # desktop left vertical monitor
            mode = "3840x2160@60Hz";
            transform = "270";
            scale = "1.5";
            position = "0,0";
          };
        };

        workspaceOutputAssign =
          (
            map
            (ws: {
              output = "GIGA-BYTE TECHNOLOGY CO., LTD. AORUS FO48U 23070B000307";
              workspace = toString ws;
            })
            (lib.range 1 7)
          )
          ++ (
            map
            (ws: {
              output = "Dell Inc. DELL U2720Q D3TM623";
              workspace = toString ws;
            })
            (lib.range 8 9)
          );
      };
    };
  };
}
