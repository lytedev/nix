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
  networking.hostId = "00482f0a";

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
    ];
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "thunderbolt"
    ];
    kernelModules = [ "kvm-amd" ];
  };

  imports = with hardware; [
    diskoConfigurations.foxtrotZfs
    framework-13-7040-amd
  ];

  networking.networkmanager = {
    wifi = {
      macAddress = "random";
      powersave = false;
    };
  };
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

  programs.steam.enable = true;
  networking.wifi.enable = true;
  lyte.desktop = {
    enable = true;
    # environment = "plasma";
  };
  lyte.laptop.enable = true;
  family-account.enable = true;
  podman.enable = true;
  home-manager.users.daniel = {
    lyte.shell = {
      enable = true;
      learn-jujutsu-not-git.enable = true;
    };
    lyte.desktop = {
      enable = true;
      environment = "gnome";
    };
    home = {
      file.".config/easyeffects/output" = {
        enable = true;
        source = fetchGit {
          url = "https://github.com/ceiphr/ee-framework-presets";
          rev = "27885fe00c97da7c441358c7ece7846722fd12fa";
        };
      };
    };
    services.easyeffects = {
      enable = true;
      preset = "philonmetal";
    };
  };
  services.postgresql.enable = true;
  environment.systemPackages = with pkgs; [ vibe ];
}
