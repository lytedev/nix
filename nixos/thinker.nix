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
    # kernelParams = ["boot.shell_on_fail"];
    initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci"];
  };

  home-manager.users.daniel = {
    programs.hyprlock.settings = {
      label = [
        {
          monitor = "";
          font_size = 32;

          halign = "center";
          valign = "center";
          text_align = "center";
          color = "rgba(255, 255, 255, 0.5)";

          position = "0 -500";
          font_family = "IosevkaLyteTerm";
          text = "cmd[update:30000] acpi";

          shadow_passes = 3;
          shadow_size = 1;
          shadow_color = "rgba(0, 0, 0, 1.0)";
          shadow_boost = 1.0;
        }
      ];
    };
    services.hypridle = let
      secondsPerMinute = 60;
      lockSeconds = 10 * secondsPerMinute;
    in {
      settings = {
        listener = [
          {
            timeout = lockSeconds + 55;
            on-timeout = ''systemctl suspend'';
          }
        ];
      };
    };

    wayland.windowManager.hyprland = {
      settings = {
        exec-once = [
          "eww open bar0"
        ];
        # See https://wiki.hyprland.org/Configuring/Keywords/ for more
        monitor = [
          "eDP-1,1920x1080@60Hz,0x0,1.0"
        ];
      };
    };
  };

  hardware.bluetooth.enable = true;
}
