{...}: {
  networking.hostName = "thinker";

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    /*
    sudo filefrag -v /swap/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}'
    the above won't work for btrfs, instead you need
    btrfs inspect-internal map-swapfile -r /swap/swapfile
    https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Hibernation_into_swap_file
    */
    kernelParams = ["boot.shell_on_fail"];
    initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci"];
  };

  hardware.bluetooth.enable = true;
}
