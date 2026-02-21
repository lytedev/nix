{
  pkgs,
  lib,
  config,
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

      # Power management
      "nowatchdog" # disable NMI watchdog to allow deeper C-states
      "amdgpu.abmlevel=3" # adaptive backlight management
    ];
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "thunderbolt"
    ];
    kernelModules = [ "kvm-amd" ];
    binfmt.emulatedSystems = [
      "aarch64-linux"
      "riscv64-linux"
    ];
  };

  imports = with hardware; [
    diskoConfigurations.foxtrotZfs
    framework-13-7040-amd
  ];

  # networking.wireless.iwd = {
  # enable = true;
  # settings = {
  #   Network.EnableIPv6 = true;
  #   Settings.AutoConnect = true;
  #   General.AddressRandomization = "network";
  # };
  # };
  networking.networkmanager = {
    wifi = {
      # macAddress = "random";
      # powersave = false;
      # backend = "iwd";
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

  programs.nix-ld.enable = true;

  # Let power-profiles-daemon manage the CPU governor via amd_pstate EPP
  powerManagement.powertop.enable = true;
  services = {
    fwupd.extraRemotes = [ "lvfs-testing" ];
    power-profiles-daemon = {
      enable = true;
    };
    fprintd = {
      enable = true;
    };
  };

  systemd.services.fprintd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "simple";
  };

  programs.steam.enable = true;
  networking.wifi.enable = true;
  lyte.desktop = {
    enable = true;
    # environment = "plasma";
    # cosmic.enable = false;
    gnome.enable = true;
    niri.enable = true;
  };
  lyte.laptop.enable = true;
  family-account.enable = true;
  podman.enable = true;
  sops = {
    secrets.claude-matrix-webhook = {
      sopsFile = ../../secrets/workstations/secrets.yml;
      mode = "0400";
      owner = "daniel";
    };
    secrets.claude-matrix-webhook-hive = {
      sopsFile = ../../secrets/workstations/secrets.yml;
      mode = "0400";
      owner = "daniel";
    };
    secrets.claude-matrix-webhook-code-review = {
      sopsFile = ../../secrets/workstations/secrets.yml;
      mode = "0400";
      owner = "daniel";
    };
  };

  lyte.shell.enable = true;
  lyte.push-to-talk.enable = true;
  lyte.claude = {
    enable = true;
    sfxPath = "${config.users.users.daniel.home}/Documents/wc3sfx/peon/sounds";
    matrixWebhooks = {
      notify = config.sops.secrets.claude-matrix-webhook.path;
      hive = config.sops.secrets.claude-matrix-webhook-hive.path;
      code-review = config.sops.secrets.claude-matrix-webhook-code-review.path;
    };
  };
  lyte.desktop.easyeffects = {
    enable = true;
    preset = "philonmetal";
    presetsSource = fetchGit {
      url = "https://github.com/ceiphr/ee-framework-presets";
      rev = "27885fe00c97da7c441358c7ece7846722fd12fa";
    };
  };
  services.postgresql.enable = true;
  environment.systemPackages = with pkgs; [ vibe ];
}
