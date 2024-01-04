{
  flake,
  inputs,
  outputs,
  lib,
  config,
  modulesPath,
  ...
}: {
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      inputs.disko.nixosModules.disko
      flake.diskoConfigurations.standard
      inputs.hardware.nixosModules.lenovo-thinkpad-x1-yoga
    ]
    ++ (with outputs.nixosModules; [
      desktop-usage
      gnome
      wifi
      flanfam
      flanfamkiosk
    ]);

  nixpkgs = {
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages
    ];
    config = {
      allowUnfree = true;
    };
  };

  nix = {
    registry = lib.mapAttrs (_: value: {flake = value;}) inputs;
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
    };
  };

  # not necessarily "base", but all my machines are UEFI so...
  boot.loader.systemd-boot.enable = true;

  services.fprintd = {
    enable = true;
    # tod.enable = true;
    # tod.driver = pkgs.libfprint-2-tod1-goodix;
  };

  environment.systemPackages =
    #with pkgs;
    [];

  programs.steam.enable = true;
  programs.steam.remotePlay.openFirewall = true;

  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [22];
      allowedUDPPorts = [];
    };
  };

  # https://wiki.archlinux.org/title/Lenovo_ThinkPad_X1_Yoga_(Gen_3)#Using_acpi_call
  systemd.services.activate-touch-hack = {
    unitConfig = {
      Description = "Touch wake Thinkpad X1 Yoga 3rd gen hack";
      After = ["suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target"];
    };

    serviceConfig = {
      ExecStart = ''
        /bin/sh -c "echo '\\_SB.PCI0.LPCB.EC._Q2A'  > /proc/acpi/call"
      '';
    };

    wantedBy = ["suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target"];
  };

  boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "usb_storage" "sd_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = with config.boot.kernelPackages; [acpi_call];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  system.stateVersion = "23.11";
}
