{
  config,
  lib,
  inputs,
  colors,
  # outputs,
  system,
  pkgs,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  hardware.enableRedistributableFirmware = true;

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
        dogdns
        dua
        eza
        fd
        file
        fzf
        gnumake
        gron
        hexyl
        htop
        iputils
        jq
        killall
        less
        mosh
        nmap
        nettools
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
        usbutils
        watchexec
        wget
        xh
        zellij
        zstd
      ]
      ++ (with inputs.home-manager.packages.${system}; [
        home-manager
      ])
      ++ (with inputs.helix.packages.${system}; [
        helix
      ]);
  };

  users.groups.daniel = {};

  users.users = {
    daniel = {
      isNormalUser = true;
      home = "/home/daniel/.home";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev"
      ];
      group = "daniel";
      extraGroups = ["users" "wheel" "video" "dialout" "uucp"];
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

      openFirewall = lib.mkDefault false;

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

    colors = with colors; [
      bg
      red
      green
      orange
      blue
      purple
      yellow
      fg3
      fgdim
      red
      green
      orange
      blue
      purple
      yellow
      fg
    ];
  };

  networking = {
    useDHCP = lib.mkDefault true;

    firewall = {
      enable = lib.mkDefault true;
      allowPing = lib.mkDefault true;
      allowedTCPPorts = lib.mkDefault [];
      allowedUDPPorts = lib.mkDefault [];
    };

    extraHosts = ''
      ::1 host.docker.internal
      127.0.0.1 host.docker.internal
    '';
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

    registry = {
      self.flake = inputs.self;

      nixpkgs = {
        from = {
          id = "nixpkgs";
          type = "indirect";
        };
        flake = inputs.nixpkgs;
      };
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
      package = pkgs.gitFull;

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

  services.udev.extraRules = ''
    # https://betaflight.com/docs/wiki/archive/Installing-Betaflight#step-1
    # ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="2e3c", ATTRS{idProduct}=="df11", MODE="0664", GROUP="uucp"
    # ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0664", GROUP="uucp"'
  '';
}
