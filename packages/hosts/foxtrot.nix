{
  pkgs,
  hardware,
  diskoConfigurations,
  # homeConfigurations,
  ...
}:
{
  system.stateVersion = "24.11";
  networking.hostName = "foxtrot";

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    kernelParams = [
      "rtc_cmos.use_acpi_alarm=1"
      "amdgpu.sg_display=0"
      "boot.shell_on_fail=1"
      "acpi_osi=\"!Windows 2020\""
      "resume_offset=3421665"
    ];
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "thunderbolt"
    ];
    kernelModules = [ "kvm-amd" ];
  };

  imports = with hardware; [
    diskoConfigurations.foxtrot
    framework-13-7040-amd
  ];

  networking.networkmanager.wifi.powersave = false;
  hardware = {
    framework.amd-7040.preventWakeOnAC = true;
    bluetooth = {
      enable = true;
      package = pkgs.bluez.overrideAttrs (
        finalAttrs: previousAttrs: rec {
          version = "5.78";
          src = pkgs.fetchurl {
            url = "mirror://kernel/linux/bluetooth/bluez-${version}.tar.xz";
            sha256 = "sha256-gw/tGRXF03W43g9eb0X83qDcxf9f+z0x227Q8A1zxeM=";
          };
          patches = [ ];
          buildInputs = previousAttrs.buildInputs ++ [
            pkgs.python3Packages.pygments
          ];
        }
      );
    };
  };
  powerManagement.cpuFreqGovernor = "ondemand";
  services = {
    fwupd.extraRemotes = [ "lvfs-testing" ];
    power-profiles-daemon = {
      enable = true;
    };
    fprintd = {
      enable = true;
    };
  };

  networking.wifi.enable = true;
  lyte.desktop.enable = true;

  home-manager.users.daniel = {
    lyte.shell.enable = true;
    lyte.desktop.enable = true;
    services.easyeffects = {
      enable = true;
      preset = "philonmetal";
      # clone from https://github.com/ceiphr/ee-framework-presets
      # then `cp *.json ~/.config/easyeffects/output`
      # TODO: nixify this
    };
  };
}
