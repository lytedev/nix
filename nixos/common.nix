{ config, lib, pkgs, ... }: {
  users.users = {
    daniel = {
      isNormalUser = true;
      home = "/home/daniel/.home";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev"
      ];
      extraGroups = [ "wheel" "video" ];
      packages = [ ];
    };

    root = {
      openssh.authorizedKeys.keys = config.users.users.daniel.openssh.authorizedKeys.keys;
    };
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
  };

  services = {
    xserver = {
      layout = "us";
      xkbOptions = "ctrl:nocaps";
    };

    openssh = {
      enable = true;
      passwordAuthentication = false;
      permitRootLogin = "no";
    };
  };

  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
    earlySetup = true;

    # colors = [
    #   "111111"
    #   "f92672"
    #   "a6e22e"
    #   "f4bf75"
    #   "66d9ef"
    #   "ae81ff"
    #   "a1efe4"
    #   "f8f8f2"
    #   "75715e"
    #   "f92672"
    #   "a6e22e"
    #   "f4bf75"
    #   "66d9ef"
    #   "ae81ff"
    #   "a1efe4"
    #   "f9f8f5"
    # ];
  };

  networking = {
    useDHCP = lib.mkDefault true;
  };

  nix = {
    settings = {
      experimental-features = lib.mkDefault [ "nix-command" "flakes" ];
    };
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
    hostPlatform = lib.mkDefault "x86_64-linux";
  };

  programs =
    {
      fish = {
        enable = true;
      };
    };

  time = {
    timeZone = "America/Chicago";
  };

  users = {
    defaultUserShell = pkgs.fish;
  };
}
