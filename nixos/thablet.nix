{
  inputs,
  outputs,
  lib,
  config,
  modulesPath,
  ...
}: {
  networking.hostName = "thablet";

  imports = with outputs.nixosModules; [
    (modulesPath + "/installer/scan/not-detected.nix")
    outputs.diskoConfigurations.standard
    inputs.hardware.nixosModules.lenovo-thinkpad-x1-yoga
    desktop-usage
    fonts
    steam
    # gnome
    kde-plasma
    wifi
    flanfam
    flanfamkiosk
  ];

  home-manager.users.daniel = {
    imports = with outputs.homeManagerModules; [
      sway
    ];
  };

  boot.loader.systemd-boot.enable = true;

  services.fprintd = {
    # TODO: am I missing a driver? see arch wiki for this h/w
    enable = false;
    # tod.enable = true;
    # tod.driver = pkgs.libfprint-2-tod1-goodix;
  };

  environment.systemPackages =
    #with pkgs;
    [];

  # https://wiki.archlinux.org/title/Lenovo_ThinkPad_X1_Yoga_(Gen_3)#Using_acpi_call
  systemd.services.activate-touch-hack = {
    enable = true;
    description = "Touch wake Thinkpad X1 Yoga 3rd gen hack";

    unitConfig = {
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
  boot.kernelModules = ["kvm-intel" "acpi_call"];
  boot.extraModulePackages = with config.boot.kernelPackages; [acpi_call];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  system.stateVersion = "23.11";
}
