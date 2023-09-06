{ modulesPath, lib, ... }: {
  imports =
    [
      ../modules/intel.net
      ../modules/desktop-usage.nix
      ../modules/podman.nix
      ../modules/wifi.nix

      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # TODO: hibernation? I've been using [deep] in /sys/power/mem_sleep alright
  # with this machine so it may not be necessary?
  # need to measure percentage lost per day, but I think it's around 10%/day
  # it looks like I may have had hibernation working -- see ../old/third.nix

  # TODO: fonts? right now, I'm just installing to ~/.local/share/fonts

  # hardware
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" ];

  networking.hostName = "thinker";

  services.pcscd.enable = true; # why do I need this? SD card slot?
  hardware.bluetooth.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  services.printing.enable = true; # I own a printer in the year of our Lord 2023

  system.stateVersion = "23.05";
}

