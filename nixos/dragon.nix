{
  config,
  inputs,
  outputs,
  lib,
  pkgs,
  ...
}: {
  networking.hostName = "dragon";

  # support interacting with the windows drive
  boot.supportedFilesystems = ["ntfs"];

  imports = with outputs.nixosModules; [
    outputs.diskoConfigurations.standard
    inputs.hardware.nixosModules.common-cpu-amd
    inputs.hardware.nixosModules.common-pc-ssd
    outputs.nixosModules.pipewire-low-latency

    desktop-usage
    podman
    kde-plasma
    postgres
    wifi
    # hyprland
    printing
    melee
    steam
    lutris
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;
  };

  environment = {
    systemPackages = with pkgs; [
      spotify
      discord
      radeontop
      slack
      godot_4
      fractal
      jdk17
      prismlauncher
      # variety
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
      inputs.slippi.homeManagerModules.default
      {
        slippi.launcher = {
          enable = true;
          isoPath = "${config.home-manager.users.daniel.home.homeDirectory}/../games/roms/dolphin/melee.iso";
        };
      }
      hyprland
    ];

    services.mako.enable = lib.mkForce false; # don't use mako when using plasma

    wayland.windowManager.hyprland = {
      settings = {
        env = [
          "EWW_BAR_MON,1"
        ];
        # See https://wiki.hyprland.org/Configuring/Keywords/ for more
        monitor = [
          # "DP-2,3840x2160@60,-2160x0,1,transform,3"
          "DP-3,3840x2160@120,${toString (builtins.ceil (2160 / 1.5))}x0,1"
          # HDR breaks screenshare? "DP-3,3840x2160@120,${toString (builtins.ceil (2160 / 1.5))}x0,1,bitdepth,10"
          # "desc:LG Display 0x0521,3840x2160@120,0x0,1"
          # "desc:Dell Inc. DELL U2720Q D3TM623,3840x2160@60,3840x0,1.5,transform,1"
          "DP-2,3840x2160@60,0x0,1.5,transform,1"
        ];
        input = {
          force_no_accel = true;
          sensitivity = 1; # -1.0 - 1.0, 0 means no modification.
        };
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
            transform = "90";
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

  services.printing.enable = true;

  # TODO: https://nixos.wiki/wiki/Remote_LUKS_Unlocking

  # hardware
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;
  boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci"];
  boot.kernelModules = ["kvm-amd"];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [22 7777];
      allowedUDPPorts = [];
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}
