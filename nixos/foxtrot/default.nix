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
      inputs.hardware.nixosModules.common-cpu-amd
      # inputs.hardware.nixosModules.common-cpu-amd-pstate
      inputs.hardware.nixosModules.common-pc-laptop-ssd
    ];

  nixpkgs.overlays = [outputs.overlays.modifications];

  # TODO: hibernation? does sleep suffice?
  # TODO: perform a hardware scan

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    kernelParams = ["amdgpu.sg_display=0"];
    initrd.availableKernelModules = ["xhci_pci" "nvme" "thunderbolt"];
    kernelModules = ["kvm-amd"];
  };
  hardware.bluetooth.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  services.printing.enable = true;

  boot.supportedFilesystems =
    pkgs.lib.mkForce ["btrfs" "cifs" "f2fs" "jfs" "ntfs" "reiserfs" "vfat" "xfs"];

  boot.kernelPackages = pkgs.linuxPackagesFor (
    pkgs.linux_6_5.override {
      argsOverride = {
        src = pkgs.fetchurl {
          url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.5.8.tar.xz";
          sha256 = "sha256-KZzKiX2Q3qoXbuvsQvCoDut1Fq/tMwpFwU2p3ghs9xc=";
        };
        version = "6.5.8";
        modDirVersion = "6.5.8";
      };
    }
  );

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
