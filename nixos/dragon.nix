{ modulesPath, lib, ... }: {
  imports =
    [
      ../modules/amd.nix
      ../modules/desktop-usage.nix
      ../modules/podman.nix
      ../modules/wifi.nix

      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # TODO: fonts? right now, I'm just installing to ~/.local/share/fonts

  # hardware
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];

  networking.hostName = "dragon";

  hardware.bluetooth.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  services.printing.enable = true;

  networking = {
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [ 22 ];
      allowedUDPPorts = [ ];
    };
  };

  system.stateVersion = "23.11";
}

