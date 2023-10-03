{
  config,
  lib,
  inputs,
  system,
  ...
}: let
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  unstable-pkgs = inputs.nixpkgs-unstable.legacyPackages.${system};
in {
  services.journald.extraConfig = "SystemMaxUse=1G";

  environment = {
    variables = {
      EDITOR = "hx";
      VISUAL = "hx";
      PAGER = "less";
      MANPAGER = "less";
    };

    systemPackages = with pkgs;
      [
        age
        bat
        bc
        bind
        bottom
        btrfs-progs
        cue
        curl
        dog
        dua
        fd
        file
        gnumake
        gron
        helix
        hexyl
        htop
        iputils
        jq
        killall
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
        rtx
        sd
        sops
        smartmontools
        sqlite
        sysstat
        unzip
        watchexec
        wget
        xh
        zellij
        zstd
      ]
      ++ (with unstable-pkgs; [
        eza
      ]);
  };

  users.users = {
    daniel = {
      isNormalUser = true;
      home = "/home/daniel/.home";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev"
      ];
      group = "daniel";
      extraGroups = ["users" "wheel" "video"];
      packages = [];
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
      allowedTCPPorts = lib.mkDefault [22];
      allowedUDPPorts = lib.mkDefault [];
    };
  };

  nix = {
    settings = {
      trusted-users = ["root" "daniel"];
      experimental-features = lib.mkDefault ["nix-command" "flakes"];
      substituters = [
        "https://cache.nixos.org/"
        "https://helix.cachix.org"
        "https://nix-community.cachix.org"
        "https://nix.h.lyte.dev"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "h.lyte.dev:HeVWtne31ZG8iMf+c15VY3/Mky/4ufXlfTpT8+4Xbs0="
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
