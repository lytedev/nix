{
  diskoConfigurations,
  hardware,
  pkgs,
  lib,
  config,
  ...
}:
{
  system.stateVersion = "24.11";
  networking.hostName = "flipflop";

  boot.loader.systemd-boot.enable = true;

  services.fprintd = {
    # TODO: am I missing a driver? see arch wiki for this h/w
    enable = false;
    # tod.enable = true;
    # tod.driver = pkgs.libfprint-2-tod1-goodix;
  };

  environment.systemPackages =
    #with pkgs;
    [ ];

  # https://wiki.archlinux.org/title/Lenovo_ThinkPad_X1_Yoga_(Gen_3)#Using_acpi_call
  systemd.services.activate-touch-hack = {
    enable = true;
    description = "Touch wake Thinkpad X1 Yoga 3rd gen hack";

    unitConfig = {
      After = [
        "suspend.target"
        "hibernate.target"
        "hybrid-sleep.target"
        "suspend-then-hibernate.target"
      ];
    };

    serviceConfig = {
      ExecStart = ''
        /bin/sh -c "echo '\\_SB.PCI0.LPCB.EC._Q2A' > /proc/acpi/call"
      '';
    };

    wantedBy = [
      "suspend.target"
      "hibernate.target"
      "hybrid-sleep.target"
      "suspend-then-hibernate.target"
    ];
  };

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-intel"
    "acpi_call"
  ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-ocl
        intel-vaapi-driver
      ];
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  imports = with hardware; [
    (diskoConfigurations.standardEncrypted { disk = "/dev/nvme0n1"; })
    common-cpu-intel
    common-pc-ssd
  ];

  services.power-profiles-daemon = {
    enable = true;
  };

  networking = {
    firewall =
      let
        terraria = 7777;
        stardew-valley = 24642;
      in
      {
        allowedTCPPorts = [
          terraria
          stardew-valley
        ];
        allowedUDPPorts = [
          terraria
          stardew-valley
        ];
      };
  };
}
