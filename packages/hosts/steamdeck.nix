{
  diskoConfigurations,
  # hardware, # do NOT use nixos-hardware with jovian config
  ...
}:
{
  system.stateVersion = "24.11";
  networking = {
    hostName = "steamdeck";
    wifi.enable = true;
  };

  hardware.bluetooth.enable = true;
  boot = {
    # kernelPackages = pkgs.linuxPackages_latest; # do NOT use with jovian config
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
  };
  imports = [
    (diskoConfigurations.unencrypted { disk = "/dev/nvme0n1"; })
  ];

  lyte.desktop.enable = true;
  home-manager.users.daniel = {
    lyte = {
      useOutOfStoreSymlinks.enable = true;
      shell = {
        enable = true;
        learn-jujutsu-not-git.enable = true;
      };
      desktop.enable = true;
    };
  };

  nixpkgs.config.allowUnfree = true;
  programs.steam.enable = true;
  jovian = {
    decky-loader = {
      enable = true;
    };
    steam = {
      autoStart = true;
      updater = {
        splash = "jovian";
      };
    };
    hardware = {
      has.amd.gpu = true;
    };
    devices = {
      steamdeck = {
        enable = true;
        autoUpdate = true;
        # enableGyroDsuService = true;
      };
    };
  };
}
