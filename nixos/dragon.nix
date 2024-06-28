{
  pkgs,
  lib,
  config,
  ...
}: {
  system.stateVersion = "24.05";
  networking.hostName = "dragon";

  hardware.opengl.extraPackages = [
    # pkgs.rocmPackages.clr.icd
    pkgs.amdvlk

    # encoding/decoding acceleration
    pkgs.libvdpau-va-gl
    pkgs.vaapiVdpau
  ];

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;
  boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci" "usbhid"];
  boot.kernelModules = ["kvm-amd"];
  boot.supportedFilesystems = ["ntfs"];

  hardware.bluetooth = {
    enable = true;
    package = pkgs.bluez;
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
    obs-studio
  ];

  home-manager.users.daniel = {
    slippi.launcher = {
      enable = true;
      isoPath = "${config.home-manager.users.daniel.home.homeDirectory}/../games/roms/dolphin/melee.iso";
      launchMeleeOnPlay = false;
    };

    # TODO: monitor config module?
    # wayland.windowManager.hyprland = {
    #   settings = {
    #     env = [
    #       "EWW_BAR_MON,1"
    #     ];
    #     # See https://wiki.hyprland.org/Configuring/Keywords/ for more
    #     monitor = [
    #       # "DP-2,3840x2160@60,-2160x0,1,transform,3"
    #       "DP-3,3840x2160@120,${toString (builtins.ceil (2160 / 1.5))}x0,1"
    #       # HDR breaks screenshare? "DP-3,3840x2160@120,${toString (builtins.ceil (2160 / 1.5))}x0,1,bitdepth,10"
    #       # "desc:LG Display 0x0521,3840x2160@120,0x0,1"
    #       # "desc:Dell Inc. DELL U2720Q D3TM623,3840x2160@60,3840x0,1.5,transform,1"
    #       "DP-2,3840x2160@60,0x0,1.5,transform,1"
    #     ];
    #     input = {
    #       force_no_accel = true;
    #       sensitivity = 1; # -1.0 - 1.0, 0 means no modification.
    #     };
    #   };
    # };

    # wayland.windowManager.sway = {
    #   config = {
    #     output = {
    #       "GIGA-BYTE TECHNOLOGY CO., LTD. AORUS FO48U 23070B000307" = {
    #         mode = "3840x2160@120Hz";
    #         position = "${toString (builtins.ceil (2160 / 1.5))},0";
    #       };

    #       "Dell Inc. DELL U2720Q D3TM623" = {
    #         # desktop left vertical monitor
    #         mode = "3840x2160@60Hz";
    #         transform = "90";
    #         scale = "1.5";
    #         position = "0,0";
    #       };
    #     };

    #     workspaceOutputAssign =
    #       (
    #         map
    #         (ws: {
    #           output = "GIGA-BYTE TECHNOLOGY CO., LTD. AORUS FO48U 23070B000307";
    #           workspace = toString ws;
    #         })
    #         (lib.range 1 7)
    #       )
    #       ++ (
    #         map
    #         (ws: {
    #           output = "Dell Inc. DELL U2720Q D3TM623";
    #           workspace = toString ws;
    #         })
    #         (lib.range 8 9)
    #       );
    #   };
    # };
  };
}
