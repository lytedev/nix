{
  disko,
  sops-nix,
  colors,
  flakeInputs,
  homeManagerModules,
  home-manager,
  helix,
  nixosModules,
  pubkey,
  overlays,
}: {
  fallback-hostname = {lib, ...}: {
    networking.hostName = lib.mkDefault "set-a-hostname-dingus";
  };

  no-giant-logs = {lib, ...}: {
    services.journald.extraConfig = lib.mkDefault "SystemMaxUse=1G";
  };

  allow-redistributable-firmware = {lib, ...}: {
    hardware.enableRedistributableFirmware = lib.mkDefault true;
  };

  home-manager-defaults = {
    imports = [
      # enable home-manager
      home-manager.nixosModules.home-manager
    ];

    home-manager.useGlobalPkgs = true;
    home-manager.backupFileExtension = "hm-backup";
  };

  mdns-and-lan-service-discovery = {
    services.avahi = {
      enable = true;
      reflector = true;
      openFirewall = true;
      nssmdns4 = true;
    };
  };

  less-pager = {pkgs, ...}: {
    environment = {
      systemPackages = [
        pkgs.less
      ];
      variables = {
        PAGER = "less";
        MANPAGER = "less";
      };
    };
  };

  helix-text-editor = {pkgs, ...}: {
    environment = {
      systemPackages = [
        pkgs.less
        helix.packages.${pkgs.system}.helix
      ];
      variables = {
        EDITOR = "hx";
        SYSTEMD_EDITOR = "hx";
        VISUAL = "hx";
      };
    };
  };

  zellij-multiplexer = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.zellij
    ];
  };

  fish-shell = {
    pkgs,
    lib,
    ...
  }: {
    programs.fish = {
      enable = true;
    };

    users = {
      defaultUserShell = pkgs.fish;
    };
  };

  nix-index = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  my-favorite-default-system-apps = {pkgs, ...}: {
    imports = with nixosModules; [
      less-pager
      helix-text-editor
      zellij-multiplexer
      fish-shell
    ];

    environment.systemPackages = with pkgs; [
      curl
      dua
      eza # TODO: needs shell aliases
      fd
      file
      iputils
      nettools
      # nodePackages.bash-language-server # just pull in as needed?
      # shellcheck
      # shfmt
      killall
      ripgrep
      rsync
      sd
    ];

    programs = {
      traceroute.enable = true;
      git = {
        enable = true;
        package = pkgs.gitFull;
        lfs.enable = true;
      };
    };
  };

  mosh = {lib, ...}: {
    programs.mosh = {
      enable = true;
      openFirewall = lib.mkDefault true;
    };
  };

  ssh-server = {lib, ...}: {
    # enable an ssh server and provide root access with my primary public key

    users.users.root = {
      openssh.authorizedKeys.keys = [pubkey];
    };

    services.openssh = {
      enable = true;

      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };

      openFirewall = lib.mkDefault true;

      # listenAddresses = [
      #   { addr = "0.0.0.0"; port = 22; }
      # ];
    };
  };

  password-manager = {pkgs, ...}: {
    # programs.goldwarden = {
    # NOTE: This didn't seem to work for me, but would be awesome!
    #   enable = true;
    # };

    home-manager.users.daniel = {
      imports = with homeManagerModules; [
        password-manager
      ];
    };
  };

  linux = {pkgs, ...}: {
    home-manager.users.daniel = {
      imports = with homeManagerModules; [
        linux
      ];
    };
  };

  tailscale = {lib, ...}: {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = lib.mkDefault "client";
    };
  };

  default-nix-configuration-and-overlays = {
    lib,
    config,
    ...
  }: {
    nixpkgs = {
      overlays = with overlays; [
        additions
        modifications
        unstable-packages
      ];
      config.allowUnfree = true;
    };

    nix = {
      nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
      registry = lib.mapAttrs (_: value: {flake = value;}) flakeInputs;

      settings = {
        trusted-users = ["root" "daniel"];
        experimental-features = lib.mkDefault ["nix-command" "flakes"];

        substituters = [
          # TODO: dedupe with flake's config? is that even necessary?
          "https://cache.nixos.org/"
          "https://helix.cachix.org"
          "https://nix-community.cachix.org"
          # "https://nix.h.lyte.dev"
          "https://hyprland.cachix.org"
        ];
        trusted-public-keys = [
          # TODO: dedupe with flake's config? is that even necessary?
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "h.lyte.dev:HeVWtne31ZG8iMf+c15VY3/Mky/4ufXlfTpT8+4Xbs0="
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        ];
        auto-optimise-store = true;
      };
    };
  };

  laptop = {pkgs, ...}: {
    imports = with nixosModules; [
      family-users
      wifi
    ];

    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
      ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
    '';
  };

  development-tools = {pkgs, ...}: {
    imports = with nixosModules; [
      postgres
      podman
      troubleshooting-tools
    ];

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    programs.neovim = {
      enable = true;
      # plugins = [
      #   pkgs.vimPlugins.nvim-treesitter.withAllGrammars
      # ];
    };

    environment.systemPackages = with pkgs; [
      taplo # toml language server for editing helix configs per repo
      pgcli
      oil
      watchexec
      android-tools
      kubectl
      stern
      libresprite
      logseq
      audacity
      wol
      shellcheck
      skim
      sops
      gron
      shfmt
      vscode-langservers-extracted
      nodePackages.bash-language-server
      nodePackages.yaml-language-server
      xh
      curl
      google-chrome
    ];

    hardware.gpgSmartcards.enable = true;

    services.udev.packages = with pkgs; [
      # TODO: I think these get the whole package pulled in... should find out
      # if there's a way to get just the rules and not 4 chromes
      platformio
      openocd
      pkgs.yubikey-personalization
      via
    ];

    programs.adb.enable = true;
    users.users.daniel.extraGroups = ["adbusers"];

    home-manager.users.daniel = {
      home.packages = with pkgs; [
        yubikey-personalization
        yubikey-manager
        yubico-piv-tool
      ];

      programs.thunderbird = {
        enable = true;

        profiles = {
          daniel = {
            isDefault = true;
            # name = "daniel";
          };
        };
      };

      programs.nushell = {
        enable = true;
      };

      programs.jujutsu = {
        enable = true;
      };

      programs.k9s = {
        enable = true;
      };

      programs.vscode = {
        enable = true;
      };

      programs.jq = {
        enable = true;
      };

      programs.chromium = {
        enable = true;
      };

      programs.btop = {
        enable = true;
        package = pkgs.btop.override {
          rocmSupport = true;
        };
      };
    };
  };

  troubleshooting-tools = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      bottom
      btop
      dnsutils
      dogdns
      htop
      inetutils
      nmap
      pciutils
      usbutils
    ];
  };

  graphical-workstation = {pkgs, ...}: {
    imports = with nixosModules; [
      plasma6
      fonts
      development-tools
      printing
    ];

    xdg.portal.enable = true;

    hardware = {
      opengl = {
        enable = true;
        driSupport32Bit = true;
        driSupport = true;
      };
    };
    environment = {
      systemPackages = with pkgs; [
        libnotify
      ];
      variables = {
        # GTK_THEME = "Catppuccin-Mocha-Compact-Sapphire-Dark";
        # GTK_USE_PORTAL = "1";
      };
    };
  };

  # ewwbar = {};
  # gnome = {};
  # hyprland = {};
  # intel = {};

  kde-connect = {
    programs.kdeconnect.enable = true;

    # networking.firewall = {
    # allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
    # allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
    # };
  };

  fonts = {pkgs, ...}: {
    fonts.packages = with pkgs; [
      (nerdfonts.override {fonts = ["NerdFontsSymbolsOnly"];})
      pkgs.iosevkaLyteTerm
    ];
  };

  plasma6 = {
    pkgs,
    lib,
    ...
  }: {
    imports = with nixosModules; [
      kde-connect
      pipewire
    ];

    services.xserver.enable = true;
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
    services.desktopManager.plasma6.enable = true;
    programs.dconf.enable = true;

    services.xrdp.enable = false;
    services.xrdp.defaultWindowManager = "plasma";
    services.xrdp.openFirewall = false;

    environment.systemPackages = with pkgs; [
      wl-clipboard
      inkscape
      krita
      noto-fonts
      vlc
      wl-clipboard

      kdePackages.qtvirtualkeyboard
      maliit-keyboard
      maliit-framework

      kdePackages.kate
      # kdePackages.kdenlive
      # kdePackages.merkuro
      kdePackages.kcalc
      # kdePackages.neochat
      kdePackages.filelight
      kdePackages.krdc
      kdePackages.krfb
      kdePackages.kclock
      kdePackages.kweather
      kdePackages.ktorrent
      # kdePackages.kdevelop
      # kdePackages.kdialog
      kdePackages.kdeplasma-addons

      unstable-packages.kdePackages.krdp
    ];

    programs.gnupg.agent.pinentryPackage = pkgs.pinentry-tty;
  };

  lutris = {pkgs, ...}: {
    environment = {
      systemPackages = with pkgs; [
        wineWowPackages.waylandFull
        lutris
        winetricks
      ];
    };
  };

  gaming = {
    imports = with nixosModules; [
      lutris
      steam
    ];
  };

  pipewire = {
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      # wireplumber.enable = true; # this is default now
      wireplumber.extraConfig = {
        "monitor.bluez.properties" = {
          "bluez5.enable-sbc-xq" = true;
          "bluez5.enable-msbc" = true;
          "bluez5.enable-hw-volume" = true;
          "bluez5.roles" = ["hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag"];
        };
      };
      extraConfig.pipewire."91-null-sinks" = {
        "context.objects" = [
          {
            # A default dummy driver. This handles nodes marked with the "node.always-driver"
            # properyty when no other driver is currently active. JACK clients need this.
            factory = "spa-node-factory";
            args = {
              "factory.name" = "support.node.driver";
              "node.name" = "Dummy-Driver";
              "priority.driver" = 8000;
            };
          }
          {
            factory = "adapter";
            args = {
              "factory.name" = "support.null-audio-sink";
              "node.name" = "Microphone-Proxy";
              "node.description" = "Microphone";
              "media.class" = "Audio/Source/Virtual";
              "audio.position" = "MONO";
            };
          }
          {
            factory = "adapter";
            args = {
              "factory.name" = "support.null-audio-sink";
              "node.name" = "Main-Output-Proxy";
              "node.description" = "Main Output";
              "media.class" = "Audio/Sink";
              "audio.position" = "FL,FR";
            };
          }
        ];
      };
      # extraConfig.pipewire."92-low-latency" = {
      # context.properties = {
      # default.clock.rate = 48000;
      # default.clock.quantum = 32;
      # default.clock.min-quantum = 32;
      # default.clock.max-quantum = 32;
      # };
      # };
    };

    # recommended by https://nixos.wiki/wiki/PipeWire
    security.rtkit.enable = true;

    # services.pipewire = {
    #   enable = true;

    #   wireplumber.enable = true;
    #   pulse.enable = true;
    #   jack.enable = true;

    #   alsa = {
    #     enable = true;
    #     support32Bit = true;
    #   };
    # };

    # hardware = {
    #   pulseaudio = {
    #     enable = false;
    #     support32Bit = true;
    #   };
    # };

    # security = {
    #   # I forget why I need these exactly...
    #   polkit.enable = true;

    #   rtkit.enable = true;
    # };
  };

  music-production = {pkgs, ...}: {
    # TODO: may want to force nixpkgs-stable for a more-stable music production
    # environment?
    imports = [
      {
        environment.systemPackages = with pkgs; [
          helvum # pipewire graph/patchbay GUI
          ardour # DAW
          helm # synth
        ];
      }
    ];

    # TODO: things to look into for music production:
    # - https://linuxmusicians.com/viewtopic.php?t=27016
    # - KXStudio?
    # - falktx (https://github.com/DISTRHO/Cardinal)
    # -
  };

  podman = {pkgs, ...}: {
    environment = {
      systemPackages = with pkgs; [
        podman-compose
      ];
    };

    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };

      oci-containers = {
        backend = "podman";
      };
    };
  };

  postgres = {pkgs, ...}: {
    # this is really just for development usage
    services.postgresql = {
      enable = true;
      ensureDatabases = ["daniel"];
      ensureUsers = [
        {
          name = "daniel";
          ensureDBOwnership = true;
        }
      ];
      # enableTCPIP = true;

      package = pkgs.postgresql_15;

      authentication = pkgs.lib.mkOverride 10 ''
        #type database  DBuser    auth-method
        local all       postgres  peer map=superuser_map
        local all       daniel    peer map=superuser_map
        local sameuser  all       peer map=superuser_map

        # lan ipv4
        host  all       all     10.0.0.0/24   trust
        host  all       all     127.0.0.1/32  trust

        # tailnet ipv4
        host       all       all     100.64.0.0/10 trust
      '';

      identMap = ''
        # ArbitraryMapName systemUser DBUser
        superuser_map      root       postgres
        superuser_map      postgres   postgres
        superuser_map      daniel     postgres

        superuser_map      /^(.*)$    \1       # Let other names login as themselves
      '';
    };

    environment.systemPackages = with pkgs; [
      pgcli
    ];
  };

  printing = {pkgs, ...}: {
    services.printing.enable = true;
    services.printing.browsing = true;
    services.printing.browsedConf = ''
      BrowseDNSSDSubTypes _cups,_print
      BrowseLocalProtocols all
      BrowseRemoteProtocols all
      CreateIPPPrinterQueues All

      BrowseProtocols all
    '';
    services.printing.drivers = [pkgs.gutenprint];
  };

  sway = {};

  enable-flatpaks-and-appimages = {
    services.flatpak.enable = true;
    programs.appimage.binfmt = true;
  };

  wifi = {lib, ...}: let
    inherit (lib) mkDefault;
  in {
    networking.networkmanager.enable = mkDefault true;
    systemd.services.NetworkManager-wait-online.enable = mkDefault false;

    # TODO: networking.networkmanager.wifi.backend = "iwd"; ?
    # TODO: powersave?
    # TODO: can I pre-configure my usual wifi networks with SSIDs and PSKs loaded from secrets?
  };

  steam = {pkgs, ...}: {
    # programs.gamescope.enable = true;

    programs.steam = {
      enable = true;
      # extest.enable = true;
      # gamescopeSession.enable = true;

      # extraPackages = with pkgs; [
      # gamescope
      # ];

      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];

      localNetworkGameTransfers.openFirewall = true;
      remotePlay.openFirewall = true;
    };

    hardware.steam-hardware.enable = true;
    services.udev.packages = with pkgs; [steam];

    environment.systemPackages = with pkgs; [
      dualsensectl # for interfacing with dualsense controllers programmatically
    ];

    # remote play ports - should be unnecessary due to programs.steam.remotePlay.openFirewall = true;
    # networking.firewall.allowedUDPPortRanges = [ { from = 27031; to = 27036; } ];
    # networking.firewall.allowedTCPPortRanges = [ { from = 27036; to = 27037; } ];
  };

  daniel = {pkgs, ...}: let
    username = "daniel";
  in {
    users.groups.${username} = {};
    users.users.${username} = {
      isNormalUser = true;
      home = "/home/${username}/.home";
      createHome = true;
      openssh.authorizedKeys.keys = [pubkey];
      group = username;
      extraGroups = ["users" "wheel" "video" "dialout" "uucp"];
      packages = [];
    };
    home-manager.users.daniel = {
      imports = [homeManagerModules.common];

      home = {
        username = "daniel";
        homeDirectory = "/home/daniel/.home";
        stateVersion = pkgs.lib.mkDefault "24.05";
      };

      accounts.email.accounts = {
        primary = {
          primary = true;
          address = "daniel@lyte.dev";
        };
        legacy = {
          address = "wraithx2@gmail.com";
        };
        io = {
          # TODO: finalize deprecation
          address = "daniel@lytedev.io";
        };
      };
    };
  };

  valerie = let
    username = "valerie";
  in {
    users.groups.${username} = {};
    users.users.${username} = {
      isNormalUser = true;
      home = "/home/${username}";
      createHome = true;
      openssh.authorizedKeys.keys = [pubkey];
      group = username;
      extraGroups = ["users" "video"];
      packages = [];
    };
  };

  flanfam = let
    username = "flanfam";
  in {
    users.groups.${username} = {};
    users.users.${username} = {
      isNormalUser = true;
      home = "/home/${username}";
      createHome = true;
      openssh.authorizedKeys.keys = [pubkey];
      group = username;
      extraGroups = ["users" "video"];
      packages = [];
    };
  };

  family-users = {
    imports = with nixosModules; [
      # daniel # part of common
      valerie
      flanfam
    ];
  };

  # a common module that is intended to be imported by all NixOS systems
  common = {
    lib,
    pkgs,
    modulesPath,
    ...
  }: {
    imports = with nixosModules; [
      (modulesPath + "/installer/scan/not-detected.nix")
      default-nix-configuration-and-overlays

      # allow any machine to make use of sops secrets
      sops-nix.nixosModules.sops

      # allow disko modules to manage disk config
      disko.nixosModules.disko

      fallback-hostname
      no-giant-logs
      allow-redistributable-firmware
      mdns-and-lan-service-discovery
      tailscale
      ssh-server

      my-favorite-default-system-apps
      mosh

      home-manager-defaults

      daniel
    ];

    programs.gnupg.agent = {
      enable = true;
      pinentryPackage = lib.mkDefault pkgs.pinentry-tty;
    };

    time = {
      timeZone = lib.mkDefault "America/Chicago";
    };

    i18n = {
      defaultLocale = lib.mkDefault "en_US.UTF-8";
    };

    services = {
      xserver.xkb = {
        layout = lib.mkDefault "us";

        # have the caps-lock key instead be a ctrl key
        options = lib.mkDefault "ctrl:nocaps";
      };
      smartd.enable = true;
      fwupd.enable = true;
    };

    console = {
      # font = "Lat2-Terminus16"; # TODO: would like this font for non-hidpi displays, but this is not dynamic enough?
      useXkbConfig = lib.mkDefault true;
      earlySetup = lib.mkDefault true;

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
      };
    };

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    system.stateVersion = lib.mkDefault "24.05";
  };

  # intended to be auto-logged in and only run a certain application
  # flanfamkiosk = {};
}
