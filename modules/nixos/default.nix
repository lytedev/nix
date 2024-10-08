{
  disko,
  sops-nix,
  style,
  flakeInputs,
  homeManagerModules,
  home-manager,
  home-manager-unstable,
  helix,
  nixosModules,
  pubkey,
  overlays,
}: {
  ewwbar = {pkgs, ...}: {
    # imports = with nixosModules;  [];
    environment.systemPackages = with pkgs; [eww upower jq];

    # TODO: include the home-manager modules for daniel?
  };

  hyprland = {pkgs, ...}: {
    imports = with nixosModules; [
      ewwbar
      pipewire
    ];

    programs.hyprland = {
      enable = true;
    };
    environment.systemPackages = with pkgs; [hyprpaper xwaylandvideobridge socat];

    programs.hyprland = {
      package = flakeInputs.hyprland.packages.${pkgs.system}.hyprland;
    };

    # TODO: include the home-manager modules for daniel?
  };

  sway = {pkgs, ...}: {
    imports = with nixosModules; [
      pipewire
    ];

    home-manager.users.daniel = {
      imports = with homeManagerModules; [
        sway
      ];
    };

    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
    };

    # services.xserver.libinput.enable = true;

    # TODO: a lot of this probably needs de-duping with hyprland?

    services.gnome.gnome-keyring.enable = true;

    xdg.portal = {
      enable = true;
      wlr.enable = true;

      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
      ];
    };

    services.dbus.enable = true;
    security.polkit.enable = true; # needed for home-manager integration

    programs.thunar = {
      enable = true;
      plugins = with pkgs.xfce; [thunar-archive-plugin thunar-volman];
    };

    services.gvfs = {
      enable = true;
    };

    environment = {
      variables = {
        VISUAL = "hx";
        PAGER = "less";
        MANPAGER = "less";
      };

      systemPackages = with pkgs; [
        brightnessctl
        feh
        grim
        libinput
        libinput-gestures
        libnotify
        mako
        noto-fonts
        pamixer
        playerctl
        pulseaudio
        pulsemixer
        slurp
        swaybg
        swayidle
        swaylock
        swayosd
        tofi
        waybar
        wl-clipboard
        zathura

        /*
        gimp
        inkscape
        krita
        lutris
        nil
        nixpkgs-fmt
        pavucontrol
        rclone
        restic
        steam
        vlc
        vulkan-tools
        weechat
        wine
        */
      ];
    };
  };

  deno-netlify-ddns-client = import ./deno-netlify-ddns-client.nix;

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

  home-manager-unstable-defaults = {
    imports = [
      # enable home-manager
      home-manager-unstable.nixosModules.home-manager
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
      /*
      nodePackages.bash-language-server # just pull in as needed?
      shellcheck
      shfmt
      */
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

  remote-disk-key-entry-on-boot = {
    lib,
    pkgs,
    ...
  }: {
    /*
    https://nixos.wiki/wiki/Remote_disk_unlocking
    "When using DHCP, make sure your computer is always attached to the network and is able to get an IP adress, or the boot process will hang."
    ^ seems less than ideal
    */
    boot.kernelParams = ["ip=dhcp"];
    boot.initrd = {
      # availableKernelModules = ["r8169"]; # ethernet drivers
      systemd.users.root.shell = "/bin/cryptsetup-askpass";
      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 22;
          authorizedKeys = [pubkey];
          hostKeys = ["/etc/secrets/initrd/ssh_host_rsa_key"];
        };
      };
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

      /*
      listenAddresses = [
        { addr = "0.0.0.0"; port = 22; }
      ];
      */
    };
  };

  password-manager = {pkgs, ...}: {
    /*
    programs.goldwarden = {
      ## NOTE: This didn't seem to work for me, but would be awesome! (but I can't remember why?)
      enable = true;
    };
    */

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
      # registry = lib.mapAttrs (_: value: {flake = value;}) flakeInputs;

      settings = {
        trusted-users = ["root" "daniel"];
        experimental-features = lib.mkDefault ["nix-command" "flakes"];

        substituters = [
          # TODO: dedupe with flake's config? is that even necessary?
          "https://cache.nixos.org/"
          "https://helix.cachix.org"
          "https://nix-community.cachix.org"
          "https://nix.h.lyte.dev"
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

    services.upower.enable = true;

    # NOTE: I previously let plasma settings handle this
    services.logind = {
      lidSwitch = "suspend-then-hibernate";
      extraConfig = ''
        HandleLidSwitchDocked=ignore
        HandlePowerKey=suspend-then-hibernate
        IdleActionSec=11m
        IdleAction=suspend-then-hibernate
      '';
    };
  };

  emacs = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      emacs
    ];

    home-manager.users.daniel = {
      imports = with homeManagerModules; [
        emacs
      ];
    };
  };

  development-tools = {pkgs, ...}: {
    imports = with nixosModules; [
      postgres
      podman
      troubleshooting-tools
      emacs
    ];

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    programs.neovim = {
      enable = true;
      /*
      plugins = [
        pkgs.vimPlugins.nvim-treesitter.withAllGrammars
      ];
      */
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
      # logseq
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
      comma
      iftop
      bottom
      btop
      dnsutils
      dogdns
      htop
      inetutils
      nmap
      pciutils
      hexyl
      pkgs.unixtools.xxd
      usbutils
      comma
    ];
  };

  music-consumption = {pkgs, ...}: {
    environment = {
      systemPackages = with pkgs; [
        spotube
        spotdl
      ];
    };
  };

  video-tools = {pkgs, ...}: {
    environment = {
      systemPackages = with pkgs; [
        ffmpeg-full
        obs-studio
      ];
    };
  };

  graphical-workstation = {
    pkgs,
    lib,
    options,
    config,
    ...
  }: {
    imports = with nixosModules; [
      sway
      # hyprland
      enable-flatpaks-and-appimages
      fonts
      development-tools
      printing
      music-consumption
      video-tools
    ];

    xdg.portal.enable = true;

    hardware =
      if builtins.hasAttr "graphics" options.hardware
      then {
        graphics = {
          enable = true;
          /*
          driSupport32Bit = true;
          driSupport = true;
          */
        };
      }
      else {
        opengl = {
          enable = true;
          driSupport32Bit = true;
          driSupport = true;
        };
      };
    environment = {
      systemPackages = with pkgs; [
        libnotify
        slides
      ];
      variables = {
        /*
        GTK_THEME = "Catppuccin-Mocha-Compact-Sapphire-Dark";
        GTK_USE_PORTAL = "1";
        */
      };
    };
  };

  # gnome = {};
  # intel = {};

  kde-connect = {
    programs.kdeconnect.enable = true;

    /*
    # handled by enabling
    networking.firewall = {
    allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
    allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
    };
    */
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
      kdePackages.kcalc
      kdePackages.filelight
      kdePackages.krdc
      kdePackages.krfb
      kdePackages.kclock
      kdePackages.kweather
      kdePackages.ktorrent
      kdePackages.kdeplasma-addons

      unstable-packages.kdePackages.krdp

      /*
      kdePackages.kdenlive
      kdePackages.merkuro
      kdePackages.neochat
      kdePackages.kdevelop
      kdePackages.kdialog
      */
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

  gaming = {pkgs, ...}: {
    imports = with nixosModules; [
      lutris
      steam
    ];

    environment = {
      systemPackages = with pkgs; [
        ludusavi
        # ludusavi uses rclone
        rclone
      ];
    };
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
      /*
      extraConfig.pipewire."92-low-latency" = {
      context.properties = {
      default.clock.rate = 48000;
      default.clock.quantum = 32;
      default.clock.min-quantum = 32;
      default.clock.max-quantum = 32;
      };
      };
      */
    };

    # recommended by https://nixos.wiki/wiki/PipeWire
    security.rtkit.enable = true;

    /*
    services.pipewire = {
      enable = true;

      wireplumber.enable = true;
      pulse.enable = true;
      jack.enable = true;

      alsa = {
        enable = true;
        support32Bit = true;
      };
    };

    hardware = {
      pulseaudio = {
        enable = false;
        support32Bit = true;
      };
    };

    security = {
      # I forget why I need these exactly...
      polkit.enable = true;

      rtkit.enable = true;
    };
    */
  };

  music-production = {pkgs, ...}: {
    /*
    TODO: may want to force nixpkgs-stable for a more-stable music production
    environment?
    */
    imports = [
      {
        environment.systemPackages = with pkgs; [
          helvum # pipewire graph/patchbay GUI
          ardour # DAW
          helm # synth
        ];
      }
    ];

    /*
    TODO: things to look into for music production:
    - https://linuxmusicians.com/viewtopic.php?t=27016
    - KXStudio?
    - falktx (https://github.com/DISTRHO/Cardinal)
    */
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
        dockerSocket.enable = true;
        defaultNetwork.settings.dns_enabled = true;
        # networkSocket.enable = true;
      };

      oci-containers = {
        backend = "podman";
      };
    };
  };

  virtual-machines = {pkgs, ...}: {
    virtualisation.libvirtd.enable = true;
    users.users.daniel.extraGroups = ["libvirtd"];
  };

  virtual-machines-gui = {pkgs, ...}: {
    programs.virt-manager.enable = true;
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

  enable-flatpaks-and-appimages = {
    services.flatpak.enable = true;
    programs.appimage.binfmt = true;
  };

  wifi = {lib, ...}: let
    inherit (lib) mkDefault;
  in {
    networking.networkmanager.enable = mkDefault true;
    systemd.services.NetworkManager-wait-online.enable = mkDefault false;

    /*
    TODO: networking.networkmanager.wifi.backend = "iwd"; ?
    TODO: powersave?
    TODO: can I pre-configure my usual wifi networks with SSIDs and PSKs loaded from secrets?
    */
    hardware.wirelessRegulatoryDatabase = true;
    boot.extraModprobeConfig = ''
      options cfg80211 ieee80211_regdom="US"
    '';
  };

  steam = {pkgs, ...}: {
    # programs.gamescope.enable = true;

    programs.steam = {
      enable = true;

      /*
      extest.enable = true;
      gamescopeSession.enable = true;

      extraPackages = with pkgs; [
      gamescope
      ];
      */

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
    /*
    networking.firewall.allowedUDPPortRanges = [ { from = 27031; to = 27036; } ];
    networking.firewall.allowedTCPPortRanges = [ { from = 27036; to = 27037; } ];
    */
  };

  root = {
    pkgs,
    lib,
    ...
  }: {
    users.users.root = {
      home = "/root";
      createHome = true;
      openssh.authorizedKeys.keys = [pubkey];
      shell = lib.mkForce pkgs.fish;
    };
    home-manager.users.root = {
      imports = [homeManagerModules.common];

      home = {
        username = "root";
        homeDirectory = "/root";
        stateVersion = pkgs.lib.mkDefault "24.05";
      };
    };
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

      daniel
      root
    ];

    boot.tmp.useTmpfs = true;
    systemd.services.nix-daemon = {
      environment.TMPDIR = "/var/tmp";
    };
    boot.tmp.cleanOnBoot = true;
    services.irqbalance.enable = true;

    services.kanidm = {
      enableClient = true;
      enablePam = true;
      package = pkgs.kanidm;

      clientSettings.uri = "https://idm.h.lyte.dev";
      unixSettings = {
        # hsm_pin_path = "/somewhere/else";
        pam_allowed_login_groups = [];
      };
    };

    systemd.tmpfiles.rules = [
      "d /etc/kanidm 1755 nobody users -"
    ];

    # module has the incorrect file permissions out of the box
    environment.etc = {
      /*
      "kanidm" = {
      enable = true;
        user = "nobody";
        group = "users";
        mode = "0755";
      };
      */
      "kanidm/unixd" = {
        user = "kanidm-unixd";
        group = "kanidm-unixd";
        mode = "0700";
      };
      "kanidm/config" = {
        user = "nobody";
        group = "users";
        mode = "0755";
      };
    };

    programs.gnupg.agent = {
      enable = true;
      pinentryPackage = lib.mkDefault pkgs.pinentry-tty;
    };

    time = {
      timeZone = "America/Chicago";
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

      colors = with style.colors; [
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
