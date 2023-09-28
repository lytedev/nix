{ config, lib, inputs, system, ... }:
let
  overlay = final: prev: {
    helix = prev.helix // inputs.helix.packages.${system}.helix;
    rtx = prev.rtx // inputs.rtx.packages.${system}.rtx;
  };
  pkgs = inputs.nixpkgs.legacyPackages.${system}.extend overlay;
in
{
  services.journald.extraConfig = "SystemMaxUse=1G";

  environment = {
    variables = {
      EDITOR = "hx";
      VISUAL = "hx";
      PAGER = "less";
      MANPAGER = "less";
    };

    systemPackages = with pkgs; [
      age
      bat
      bind
      bottom
      btrfs-progs
      cue
      curl
      dog
      dua
      exa
      fd
      file
      gnumake
      gron
      hexyl
      htop
      iputils
      jq
      killall
      kitty # TODO: I really just need the terminfo on servers, though, right?
      less
      mosh
      nmap
      openssl
      pciutils
      pv
      rclone
      restic
      ripgrep
      rsync
      sd
      sops
      smartmontools
      sqlite
      unzip
      watchexec
      wget
      xh
      zellij
      zstd
    ] ++ [
      inputs.helix.packages."x86_64-linux".helix
      inputs.rtx.packages."x86_64-linux".rtx
    ];
  };

  users.users = {
    daniel = {
      isNormalUser = true;
      home = "/home/daniel/.home";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev"
      ];
      group = "daniel";
      extraGroups = [ "users" "wheel" "video" ];
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

      settings = {
        PasswordAuthentication = false;
      };

      # TODO: tailscale can handle this I think...?
      openFirewall = lib.mkDefault true;

      # listenAddresses = [
      #   { addr = "0.0.0.0"; port = 22; }
      # ];
    };

    tailscale = {
      enable = true;
      useRoutingFeatures = lib.mkDefault "client";
    };

    fwupd.enable = true;
    smartd.enable = true;
  };

  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
    earlySetup = true;

    colors = [
      "111111"
      "f92672"
      "a6e22e"
      "f4bf75"
      "66d9ef"
      "ae81ff"
      "a1efe4"
      "f8f8f2"
      "75715e"
      "f92672"
      "a6e22e"
      "f4bf75"
      "66d9ef"
      "ae81ff"
      "a1efe4"
      "f9f8f5"
    ];
  };

  networking = {
    useDHCP = lib.mkDefault true;

    firewall = {
      enable = lib.mkDefault true;
      allowPing = lib.mkDefault true;
      allowedTCPPorts = lib.mkDefault [ 22 ];
      allowedUDPPorts = lib.mkDefault [ ];
    };
  };

  nix = {
    settings = {
      experimental-features = lib.mkDefault [ "nix-command" "flakes" ];
      substituters = [
        "https://nix.h.lyte.dev"
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "h.lyte.dev:HeVWtne31ZG8iMf+c15VY3/Mky/4ufXlfTpT8+4Xbs0="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
    hostPlatform = lib.mkDefault "x86_64-linux";
  };

  programs = {
    fish = {
      enable = true;
    };

    tmux = {
      enable = true;
      clock24 = true;
    };

    traceroute.enable = true;

    git = {
      enable = true;

      lfs = {
        enable = true;
      };
    };

    # https://github.com/nix-community/home-manager/issues/3113
    dconf.enable = true;
  };

  time = {
    timeZone = "America/Chicago";
  };

  users = {
    defaultUserShell = pkgs.fish;
  };
}
