{ diskoConfigurations, hardware, ... }:
{
  system.stateVersion = "24.11";
  networking.hostName = "thinker";

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "ahci"
    ];
  };

  imports = with hardware; [
    diskoConfigurations.foxtrot
    lenovo-thinkpad-t480
    common-pc-laptop-ssd
  ];

  services.livebook.enableUserService = true;
  hardware.bluetooth.enable = true;
  programs.steam.enable = true;
  networking.wifi.enable = true;
  lyte.desktop.enable = true;
  home-manager.users.daniel = {
    lyte.shell = {
      enable = true;
      learn-jujutsu-not-git.enable = true;
    };
    lyte.desktop.enable = true;
    home = {
      stateVersion = "24.11";
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
}
