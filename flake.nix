{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    # nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    disko.url = "github:nix-community/disko/master";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    # sops-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs";

    pre-commit.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    helix.url = "github:helix-editor/helix/master";
    hardware.url = "github:nixos/nixos-hardware";
    hyprland.url = "github:hyprwm/Hyprland";
    slippi.url = "github:lytedev/slippi-nix";
  };

  nixConfig = {
    extra-experimental-features = ["nix-command" "flakes"];

    extra-substituters = [
      "https://cache.nixos.org/"
      "https://helix.cachix.org"
      "https://nix-community.cachix.org"
      "https://nix.h.lyte.dev"
      "https://hyprland.cachix.org"
    ];

    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "h.lyte.dev:HeVWtne31ZG8iMf+c15VY3/Mky/4ufXlfTpT8+4Xbs0="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  outputs = {
    self,
    nixpkgs,
    # nixpkgs-unstable,
    disko,
    # sops-nix,
    pre-commit,
    home-manager,
    helix,
    hardware,
    # hyprland,
    slippi,
    ...
  }: let
    inherit (self) outputs;

    # TODO: make @ inputs unnecessary by making arguments explicit in all modules?
    systems = ["aarch64-linux" "aarch64-darwin" "x86_64-darwin" "x86_64-linux"];
    forSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: (import nixpkgs {inherit system;}).extend outputs.overlays.default;
    genPkgs = func: (forSystems (system: func (pkgsFor system)));
    pkg = callee: overrides: genPkgs (pkgs: pkgs.callPackage callee overrides);

    colors = (pkg ./lib/colors.nix {}).schemes.catppuccin-mocha-sapphire;

    # font = {
    #   name = "IosevkaLyteTerm";
    #   size = 12;
    # };

    # moduleArgs = {
    #   # inherit colors font;
    #   inherit helix slippi hyprland hardware disko home-manager;
    #   inherit (outputs) nixosModules homeManagerModules diskoConfigurations overlays;
    # };

    pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev";
  in {
    # in order to include our own packages in the overlay without causing
    # infinite recursion errors, we make sure _not_ to use any of the helper
    # functions above that involve pulling in the overlay
    packages = forSystems (system: (import nixpkgs {inherit system;}).callPackage ./packages {});

    diskoConfigurations = import ./disko;
    templates = import ./templates;
    formatter = genPkgs (p: p.alejandra);

    checks = pkg ({system}: {
      pre-commit-check = pre-commit.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
        };
      };
    }) {};

    devShells = pkg ({
      system,
      pkgs,
      mkShell,
    }: {
      default = mkShell {
        inherit (outputs.checks.${system}.pre-commit-check) shellHook;

        buildInputs = with pkgs; [
          lua-language-server
          nodePackages.bash-language-server
        ];
      };
    }) {};

    overlays = {
      # the default overlay composes all the other overlays together
      default = final: prev: {
        overlays = with outputs.overlays; [
          additions
          modifications
          # unstable-packages
        ];
      };

      additions = _final: prev: outputs.packages.${prev.system};

      modifications = final: prev: {
        final.helix = helix.outputs.packages.${final.system}.helix;
      };

      # unstable-packages = final: _prev: {
      #   final.unstable = import nixpkgs-unstable {
      #     system = final.system;
      #     config.allowUnfree = true;
      #   };
      # };
    };

    nixosModules = {
      fallback-hostname = {lib, ...}: {
        networking.hostName = lib.mkDefault "set-a-hostname-dingus";
      };

      no-giant-logs = {lib, ...}: {
        services.journald.extraConfig = lib.mkDefault "SystemMaxUse=1G";
      };

      allow-redistributable-firmware = {lib, ...}: {
        hardware.enableRedistributableFirmware = lib.mkDefault true;
      };

      home-manager = {
        imports = [
          # enable home-manager
          home-manager.nixosModules.home-manager
        ];

        home-manager.useGlobalPkgs = true;
        home-manager.useUserPkgs = true;
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
        systemPackages = [
          pkgs.less
        ];

        environment = {
          variables = {
            PAGER = "less";
            MANPAGER = "less";
          };
        };
      };

      helix-text-editor = {pkgs, ...}: {
        systemPackages = [
          pkgs.less
          helix.packages.${pkgs.system}.helix
        ];

        environment = {
          variables = {
            EDITOR = "hx";
            SYSTEMD_EDITOR = "hx";
            VISUAL = "hx";
          };
        };
      };

      zellij-multiplexer = {pkgs, ...}: {
        systemPackages = [
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
          defaultUserShell = lib.mkDefault pkgs.fish;
        };
      };

      nix-index = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        enableZshIntegration = true;
      };

      my-favorite-default-system-apps = {pkgs, ...}: {
        import = with outputs.nixosModules; [
          less-pager
          helix-text-editor
          zellij-multiplexer
          fish-shell
        ];

        systemPackages = with pkgs; [
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
          openssh.authorizedKeys.keys = pubkey;
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
          overlays = with outputs.overlays; [
            additions
            modifications
            unstable-packages
          ];

          config = {
            allowUnfree = true;
          };
        };

        nix = {
          nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
          registry = lib.mapAttrs (_: value: {flake = value;}) self.inputs;

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
        imports = with outputs.nixosModules; [
          family-users
          wifi
        ];

        services.udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
          ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
        '';
      };

      development-tools = {pkgs, ...}: {
        imports = with outputs.nixosModules; [
          postgres
          podman
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

        services.udev.packages = with pkgs; [
          platformio
          openocd
          via
        ];

        programs.adb.enable = true;
        users.users.daniel.extraGroups = ["adbusers"];

        home-manager.users.daniel = {
          home = {
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
          pciutils
          usbutils
          htop
          bottom
          nmap
          dogdns
          dnsutils
        ];
      };

      graphical-workstation = {
        imports = with outputs.nixosModules; [
          plasma6
          fonts
          troubleshooting-tools
          development-tools
          printing
        ];

        hardware = {
          opengl = {
            enable = true;
            driSupport32Bit = true;
            driSupport = true;
          };
        };
        environment.variables = {
          # GTK_THEME = "Catppuccin-Mocha-Compact-Sapphire-Dark";
          # GTK_USE_PORTAL = "1";
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
        imports = with outputs.nixosModules; [
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
      };

      lutris = {pkgs, ...}: {
        environment = {
          systemPackages = with pkgs; [
            wineWowPackages.waylandFull
            lutris
            proton-ge-bin
            winetricks
          ];
        };
      };

      gaming = {
        imports = with outputs.nixosModules; [
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

            # Create a `docker` alias for podman, to use it as a drop-in replacement
            dockerCompat = true;

            # Required for containers under podman-compose to be able to talk to each other.
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

      daniel = let
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
        imports = with outputs.nixosModules; [
          daniel
          valerie
          flanfam
        ];
      };

      # a common module that is intended to be imported by all NixOS systems
      common = {
        config,
        lib,
        pkgs,
        ...
      }: {
        imports = with outputs.nixosModules; [
          default-nix-configuration-and-overlays

          # allow any machine to make use of sops secrets
          sops-nix.nixosModules.sops

          # allow disko modules to manage disk config
          disko.nixosModules.disko

          fallback-hostname
          no-giant-logs
          allow-redistributable-firmware
          mdns-and-lan-service-discovery
          us-utf8

          my-favorite-default-system-apps
          mosh

          home-manager

          daniel
        ];

        time = {
          timeZone = lib.mkDefault "America/Chicago";
        };

        i18n = {
          defaultLocale = lib.mkDefault "en_US.UTF-8";
        };

        services = {
          # have the caps-lock key instead be a ctrl key
          xserver.xkb = {
            layout = lib.mkDefault "us";
            options = lib.mkDefault "ctrl:nocaps";
          };
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
    };

    homeManagerModules = {
      bat = {};
      broot = {};
      cargo = {};
      common = {};
      desktop = {};
      ewwbar = {};
      firefox = {};
      firefox-no-tabs = {};
      fish = {};
      git = {};
      gnome = {};
      helix = {};
      htop = {};
      hyprland = {};
      iex = {};
      kitty = {};
      linux = {};
      linux-desktop = {};
      macos = {};
      mako = {};
      melee = {};
      nnn = {};
      pass = {};
      senpai = {};
      sway = {};
      sway-laptop = {};
      swaylock = {};
      tmux = {};
      wallpaper-manager = {};
      waybar = {};
      wezterm = {};
      zellij = {};
    };

    nixosConfigurations = {
      beefcake = {...}: {
        services.smartd.enable = true;
        services.fwupd.enable = true;
      };

      dragon = {
        pkgs,
        config,
        ...
      }: {
        system.stateVersion = "24.05";
        networking.hostName = "dragon";

        imports = with outputs.nixosModules; [
          outputs.diskoConfigurations.standard
          hardware.nixosModules.common-cpu-amd
          hardware.nixosModules.common-pc-ssd

          common
          wifi
          graphical-workstation
          music-production
          gaming
          slippi.nixosModules.default
          {
            # dragon hardware
            boot.loader.efi.canTouchEfiVariables = true;
            boot.loader.systemd-boot.enable = true;
            boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci"];
            boot.kernelModules = ["kvm-amd"];
            boot.supportedFilesystems = ["ntfs"];

            hardware.bluetooth = {
              enable = true;
              package = pkgs.bluez;
              settings = {
                General = {
                  AutoConnect = true;
                  MultiProfile = "multiple";
                };
              };
            };
            powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
          }
          {
            # dragon firewall
            # TODO: maybe should go in the gaming module?
            networking = {
              firewall = let
                terraria = 7777;
                stardew-valley = 24642;
                ports = [
                  terraria
                  stardew-valley
                ];
              in {
                allowedTCPPorts = ports;
                allowedUDPPorts = ports;
              };
            };
          }
        ];

        environment.systemPackages = with pkgs; [
          radeontop
          godot_4
          prismlauncher
          obs-studio
        ];

        home-manager.users.daniel = {
          imports = with outputs.homeManagerModules; [
            common
            firefox-no-tabs
            slippi.homeManagerModules.default
            {
              slippi.launcher = {
                enable = true;
                isoPath = "${config.home-manager.users.daniel.home.homeDirectory}/../games/roms/dolphin/melee.iso";
                launchMeleeOnPlay = false;
              };
            }
          ];

          # TODO: monitor config module?
          # wayland.windowManager.hyprland = {
          #   settings = {
          #     env = [
          #       "EWW_BAR_MON,1"
          #     ];
          #     # See https://wiki.hyprland.org/Configuring/Keywords/ for more
          #     monitor = [
          #       # "DP-2,3840x2160@60,-2160x0,1,transform,3"
          #       "DP-3,3840x2160@120,${toString (builtins.ceil (2160 / 1.5))}x0,1"
          #       # HDR breaks screenshare? "DP-3,3840x2160@120,${toString (builtins.ceil (2160 / 1.5))}x0,1,bitdepth,10"
          #       # "desc:LG Display 0x0521,3840x2160@120,0x0,1"
          #       # "desc:Dell Inc. DELL U2720Q D3TM623,3840x2160@60,3840x0,1.5,transform,1"
          #       "DP-2,3840x2160@60,0x0,1.5,transform,1"
          #     ];
          #     input = {
          #       force_no_accel = true;
          #       sensitivity = 1; # -1.0 - 1.0, 0 means no modification.
          #     };
          #   };
          # };

          # wayland.windowManager.sway = {
          #   config = {
          #     output = {
          #       "GIGA-BYTE TECHNOLOGY CO., LTD. AORUS FO48U 23070B000307" = {
          #         mode = "3840x2160@120Hz";
          #         position = "${toString (builtins.ceil (2160 / 1.5))},0";
          #       };

          #       "Dell Inc. DELL U2720Q D3TM623" = {
          #         # desktop left vertical monitor
          #         mode = "3840x2160@60Hz";
          #         transform = "90";
          #         scale = "1.5";
          #         position = "0,0";
          #       };
          #     };

          #     workspaceOutputAssign =
          #       (
          #         map
          #         (ws: {
          #           output = "GIGA-BYTE TECHNOLOGY CO., LTD. AORUS FO48U 23070B000307";
          #           workspace = toString ws;
          #         })
          #         (lib.range 1 7)
          #       )
          #       ++ (
          #         map
          #         (ws: {
          #           output = "Dell Inc. DELL U2720Q D3TM623";
          #           workspace = toString ws;
          #         })
          #         (lib.range 8 9)
          #       );
          #   };
          # };
        };
      };

      foxtrot = {...}: {
        imports = with outputs.nixosModules; [
          common
          laptop
        ];
      };

      thablet = {...}: {
        imports = with outputs.nixosModules; [
          common
          laptop
        ];
      };

      thinker = {...}: {
        imports = with outputs.nixosModules; [
          common
          laptop
        ];
      };
    };

    # nixosConfigurations =
    # (builtins.mapAttrs (name: {
    #   system,
    #   modules,
    #   ...
    # }:
    #   nixpkgs.lib.nixosSystem {
    #     inherit system;
    #     # specialArgs = moduleArgs;
    #     modules =
    #       [
    #         outputs.nixosModules.common
    #       ]
    #       ++ modules;
    #   }) (import ./nixos))
    # // {
    #   beefcake = nixpkgs.lib.nixosSystem {
    #     system = "x86_64-linux";
    #     specialArgs = moduleArgs;
    #     modules = [outputs.nixosModules.common ./nixos/beefcake.nix];
    #   };
    # };

    # homeConfigurations = {
    #   # TODO: non-system-specific home configurations?
    #   "deck" = let
    #     system = "x86_64-linux";
    #   in
    #     home-manager.lib.homeManagerConfiguration {
    #       pkgs = pkgsFor system;
    #       extraSpecialArgs = moduleArgs;
    #       modules = with outputs.homeManagerModules; [
    #         common
    #         {
    #           home.homeDirectory = "/home/deck";
    #           home.username = "deck";
    #           home.stateVersion = "24.05";
    #         }
    #         linux
    #       ];
    #     };
    #   workm1 = let
    #     system = "aarch64-darwin";
    #   in
    #     home-manager.lib.homeManagerConfiguration {
    #       pkgs = pkgsFor system;
    #       extraSpecialArgs = moduleArgs;
    #       modules = with outputs.homeManagerModules; [
    #         common
    #         {
    #           home.homeDirectory = "/Users/daniel.flanagan";
    #           home.username = "daniel.flanagan";
    #           home.stateVersion = "24.05";
    #         }
    #         macos
    #       ];
    #     };
    # };

    # TODO: nix-on-droid for phone terminal usage?
    # TODO: nix-darwin for work?
    # TODO: nixos ISO?
  };
}
