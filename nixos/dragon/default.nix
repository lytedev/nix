{
  flake,
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  modulesPath,
  ...
}: {
  networking.hostName = "dragon";

  boot.supportedFilesystems = ["ntfs"];

  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      inputs.disko.nixosModules.disko
      flake.diskoConfigurations.standard
      inputs.hardware.nixosModules.common-cpu-amd
      inputs.hardware.nixosModules.common-pc-ssd
      outputs.nixosModules.pipewire-low-latency
    ]
    ++ (with outputs.nixosModules; [
      melee
      desktop-usage
      podman
      postgres
      wifi
      hyprland
      ewwbar
    ])
    ++ [
      # Or modules from other flakes (such as nixos-hardware):
      # inputs.hardware.nixosModules.common-cpu-amd
      # inputs.hardware.nixosModules.common-ssd

      # You can also split up your configuration and import pieces of it here:
      # ./users.nix
    ];

  # TODO: https://nixos.wiki/wiki/Remote_LUKS_Unlocking

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: {flake = value;}) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Deduplicate and optimize nix store
      auto-optimise-store = true;
    };
  };

  # hardware
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;
  boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci"];
  boot.kernelModules = ["kvm-amd"];

  hardware.bluetooth.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
  services.printing.enable = true;

  environment = {
    systemPackages = with pkgs; [
      radeontop
    ];
  };

  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [22 7777];
      allowedUDPPorts = [];
    };
  };

  services.udev.packages = [
    pkgs.platformio
    pkgs.openocd
  ];
  programs.adb.enable = true;
  users.users.daniel.extraGroups = ["adbusers"];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.11";
}
