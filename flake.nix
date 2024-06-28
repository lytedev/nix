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
    sops-nix,
    pre-commit,
    home-manager,
    helix,
    hardware,
    # hyprland,
    slippi,
    ...
  }: let
    inherit (self) outputs;
    inherit (outputs) nixosModules homeManagerModules overlays;

    # TODO: make @ inputs unnecessary by making arguments explicit in all modules?
    systems = ["aarch64-linux" "aarch64-darwin" "x86_64-darwin" "x86_64-linux"];
    forSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: (import nixpkgs {inherit system;}).extend overlays.default;
    genPkgs = func: (forSystems (system: func (pkgsFor system)));
    pkg = callee: overrides: genPkgs (pkgs: pkgs.callPackage callee overrides);

    colors = (import ./lib/colors.nix {inherit (nixpkgs) lib;}).schemes.catppuccin-mocha-sapphire;

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
    # kind of a quirk, but package definitions are actually in the "additions"
    # overlay I did this to work around some recursion problems
    packages = genPkgs (pkgs: {inherit (pkgs) iosevkaLyteTerm iosevkaLyteTermSubset;});
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
        overlays = with overlays; [
          additions
          modifications
          # unstable-packages
        ];
      };

      additions = final: prev: let
        iosevkaLyteTerm = prev.callPackage ./packages/iosevkaLyteTerm.nix {};
      in {
        inherit iosevkaLyteTerm;
        iosevkaLyteTermSubset = prev.callPackage ./packages/iosevkaLyteTermSubset.nix {
          inherit iosevkaLyteTerm;
        };
      };

      modifications = final: prev: {
        final.helix = helix.outputs.packages.${prev.system}.helix;
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
            # modifications
            # unstable-packages
          ];
          config.allowUnfree = true;
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
        imports = with nixosModules; [
          plasma6
          fonts
          troubleshooting-tools
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

      plasma6 = {pkgs, ...}: {
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

        environment.systemPackages = with pkgs; [
          wl-clipboard
        ];

        programs.gnupg.agent = {
          enable = true;
          enableSSHSupport = true;
          pinentryPackage = pkgs.pinentry-qt;
        };
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
          daniel
          valerie
          flanfam
        ];
      };

      # a common module that is intended to be imported by all NixOS systems
      common = {
        lib,
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
      bat = {
        programs.bat = {
          enable = true;
          config = {
            theme = "ansi";
          };
          # themes = {
          #   "Catppuccin-mocha" = builtins.readFile (pkgs.fetchFromGitHub
          #     {
          #       owner = "catppuccin";
          #       repo = "bat";
          #       rev = "477622171ec0529505b0ca3cada68fc9433648c6";
          #       sha256 = "6WVKQErGdaqb++oaXnY3i6/GuH2FhTgK0v4TN4Y0Wbw=";
          #     }
          #     + "/Catppuccin-mocha.tmTheme");
          # };
        };

        home.shellAliases = {
          cat = "bat";
        };
      };

      broot = {};

      cargo = {config, ...}: {
        home.file."${config.home.homeDirectory}/.cargo/config.toml" = {
          enable = true;
          text = ''
            [build]
            rustdocflags = ["--default-theme=ayu"]
          '';
        };

        # home.sessionVariables = {
        #   RUSTDOCFLAGS = "--default-theme=ayu";
        # };
      };

      common = {
        pkgs,
        lib,
        config,
        ...
      }: {
        imports = with homeManagerModules; [
          # nix-colors.homeManagerModules.default
          fish
          bat
          homeManagerModules.helix
          git
          zellij
          # broot
          # nnn
          htop
          # tmux
        ];

        programs.home-manager.enable = true;

        # services.ssh-agent.enable = true;

        home = {
          username = lib.mkDefault "lytedev";
          homeDirectory = lib.mkDefault "/home/lytedev";
          stateVersion = lib.mkDefault "24.05";

          sessionVariables = {
            EDITOR = "hx";
            VISUAL = "hx";
            PAGER = "less";
            MANPAGER = "less";
          };

          packages = with pkgs; [
            # tools I use when editing nix code
            nil
            alejandra
            gnupg
            (pkgs.buildEnv {
              name = "my-common-scripts";
              paths = [./modules/home-manager/scripts/common];
            })
          ];
        };

        programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
        };

        programs.skim = {
          # https://github.com/lotabout/skim/issues/494
          enable = false;
          enableFishIntegration = true;
          defaultOptions = ["--no-clear-start" "--color=16"];
        };

        programs.atuin = {
          enable = true;
          enableBashIntegration = config.programs.bash.enable;
          enableFishIntegration = config.programs.fish.enable;
          enableZshIntegration = config.programs.zsh.enable;
          enableNushellIntegration = config.programs.nushell.enable;

          flags = [
            "--disable-up-arrow"
          ];

          settings = {
            auto_sync = true;
            sync_frequency = "1m";
            sync_address = "https://atuin.h.lyte.dev";
            keymap_mode = "vim-insert";
            inline_height = 20;
            show_preview = true;

            sync = {
              records = true;
            };

            dotfiles = {
              enabled = true;
            };
          };
        };

        programs.fzf = {
          # using good ol' fzf until skim sucks less out of the box I guess
          enable = true;
          # enableFishIntegration = true;
          # defaultCommand = "fd --type f";
          # defaultOptions = ["--height 40%"];
          # fileWidgetOptions = ["--preview 'head {}'"];
        };

        # TODO: regular cron or something?
        programs.nix-index = {
          enable = true;

          enableBashIntegration = config.programs.bash.enable;
          enableFishIntegration = config.programs.fish.enable;
          enableZshIntegration = config.programs.zsh.enable;
        };
      };

      desktop = {
        imports = with homeManagerModules; [
          wezterm
        ];
      };

      # ewwbar = {};

      firefox = {pkgs, ...}: {
        programs.firefox = {
          # TODO: this should be able to work on macos, no?
          # TODO: enable dark theme by default
          enable = true;

          # TODO: uses nixpkgs.pass so pass otp doesn't work
          package = pkgs.firefox.override {nativeMessagingHosts = [pkgs.passff-host];};

          # extensions = with pkgs.nur.repos.rycee.firefox-addons; [
          #   ublock-origin
          # ]; # TODO: would be nice to have _all_ my firefox stuff managed here instead of Firefox Sync maybe?

          profiles = {
            daniel = {
              id = 0;
              settings = {
                "general.smoothScroll" = true;
                "browser.zoom.siteSpecific" = true;
              };

              extraConfig = ''
                user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
                // user_pref("full-screen-api.ignore-widgets", true);
                user_pref("media.ffmpeg.vaapi.enabled", true);
                user_pref("media.rdd-vpx.enabled", true);
              '';

              userChrome = ''
                #webrtcIndicator {
                  display: none;
                }
              '';

              # userContent = ''
              # '';
            };
          };
        };
      };

      firefox-no-tabs = {
        programs.firefox = {
          profiles = {
            daniel = {
              userChrome = ''
                #TabsToolbar {
                  visibility: collapse;
                }

                #main-window[tabsintitlebar="true"]:not([extradragspace="true"]) #TabsToolbar>.toolbar-items {
                  opacity: 0;
                  pointer-events: none;
                }

                #main-window:not([tabsintitlebar="true"]) #TabsToolbar {
                  visibility: collapse !important;
                }
              '';
            };
          };
        };
      };

      fish = {pkgs, ...}: {
        home = {
          packages = [
            pkgs.gawk # used in prompt
          ];
        };

        programs.eza = {
          enable = true;
        };

        programs.fish = {
          enable = true;
          # I load long scripts from files for a better editing experience
          shellInit = builtins.readFile ./modules/home-manager/fish/shellInit.fish;
          interactiveShellInit = builtins.readFile ./modules/home-manager/fish/interactiveShellInit.fish;
          loginShellInit = "";
          functions = {
            # TODO: I think these should be loaded from fish files too for better editor experience?
            d = ''
              # --wraps=cd --description "Quickly jump to NICE_HOME (or given relative or absolute path) and list files."
              if count $argv > /dev/null
                cd $argv
              else
                cd $NICE_HOME
              end
              la
            '';

            c = ''
              if count $argv > /dev/null
                cd $NICE_HOME && d $argv
              else
                d $NICE_HOME
              end
            '';

            ltl = ''
              set d $argv[1] .
              set -l l ""
              for f in $d[1]/*
                if test -z $l; set l $f; continue; end
                if command test $f -nt $l; and test ! -d $f
                  set l $f
                end
              end
              echo $l
            '';

            has_command = "command --quiet --search $argv[1]";
          };
          shellAbbrs = {};
          shellAliases = {
            ls = "eza --group-directories-first --classify";
            l = "ls";
            ll = "ls --long --group";
            la = "ll --all";
            lA = "la --all"; # --all twice to show . and ..
            tree = "ls --tree --level=3";
            lt = "ll --sort=modified";
            lat = "la --sort=modified";
            lc = "lt --sort=accessed";
            lT = "lt --reverse";
            lC = "lc --reverse";
            lD = "la --only-dirs";
            "cd.." = "d ..";
            "cdc" = "d $XDG_CONFIG_HOME";
            "cdn" = "d $NOTES_PATH";
            "cdl" = "d $XDG_DOWNLOAD_DIR";
            "cdg" = "d $XDG_GAMES_DIR";
            ".." = "d ..";
            "..." = "d ../..";
            "...." = "d ../../..";
            "....." = "d ../../../..";
            "......" = "d ../../../../..";
            "......." = "d ../../../../../..";
            "........" = "d ../../../../../../..";
            "........." = "d ../../../../../../../..";
            p = "ping";
            dc = "docker compose";
            pc = "podman-compose";
            k = "kubectl";
            kg = "kubectl get";
            v = "$EDITOR";
            sv = "sudo $EDITOR";
            kssh = "kitty +kitten ssh";
          };
        };
      };

      git = {lib, ...}: let
        email = lib.mkDefault "daniel@lyte.dev";
      in {
        programs.git = {
          enable = true;

          userName = lib.mkDefault "Daniel Flanagan";
          userEmail = email;

          delta = {
            enable = true;
            options = {};
          };

          lfs = {
            enable = true;
          };

          # signing = {
          # signByDefault = false;
          # key = ~/.ssh/personal-ed25519;
          # };

          aliases = {
            a = "add -A";
            ac = "commit -a";
            acm = "commit -a -m";
            c = "commit";
            cm = "commit -m";
            co = "checkout";

            b = "rev-parse --symbolic-full-name HEAD";
            cnv = "commit --no-verify";
            cns = "commit --no-gpg-sign";
            cnvs = "commit --no-verify --no-gpg-sign";
            cnsv = "commit --no-verify --no-gpg-sign";

            d = "diff";
            ds = "diff --staged";
            dt = "difftool";

            f = "fetch";
            fa = "fetch --all";

            l = "log --graph --abbrev-commit --decorate --oneline --all";
            plainlog = " log --pretty=format:'%h %ad%x09%an%x09%s' --date=short --decorate";
            ls = "ls-files";
            mm = "merge master";
            p = "push";
            pf = "push --force-with-lease";
            pl = "pull";
            rim = "rebase -i master";
            s = "status";
          };

          # TODO: https://blog.scottlowe.org/2023/12/15/conditional-git-configuration/
          extraConfig = {
            commit = {
              verbose = true;
              # gpgSign = true;
            };

            tag = {
              # gpgSign = true;
              sort = "version:refname";
            };

            # include.path = local.gitconfig

            gpg.format = "ssh";
            log.date = "local";

            init.defaultBranch = "main";

            merge.conflictstyle = "zdiff3";

            push.autoSetupRemote = true;

            branch.autoSetupMerge = true;

            sendemail = {
              smtpserver = "smtp.mailgun.org";
              smtpuser = email;
              smtrpencryption = "tls";
              smtpserverport = 587;
            };

            url = {
              # TODO: how to have per-machine not-in-git configuration?
              "git@git.hq.bill.com:" = {
                insteadOf = "https://git.hq.bill.com";
              };
            };
          };
        };

        programs.fish.functions = {
          g = {
            wraps = "git";
            body = ''
              if test (count $argv) -gt 0
                git $argv
              else
                git status
              end
            '';
          };
        };
      };

      # gnome = {};

      helix = {
        config,
        pkgs,
        ...
      }: let
        inherit (pkgs) system;
      in {
        # helix rust debugger stuff
        # https://github.com/helix-editor/helix/wiki/Debugger-Configurations
        home.file."${config.xdg.configHome}/lldb_vscode_rustc_primer.py" = {
          text = ''
            import subprocess
            import pathlib
            import lldb

            # Determine the sysroot for the active Rust interpreter
            rustlib_etc = pathlib.Path(subprocess.getoutput('rustc --print sysroot')) / 'lib' / 'rustlib' / 'etc'
            if not rustlib_etc.exists():
                raise RuntimeError('Unable to determine rustc sysroot')

            # Load lldb_lookup.py and execute lldb_commands with the correct path
            lldb.debugger.HandleCommand(f"""command script import "{rustlib_etc / 'lldb_lookup.py'}" """)
            lldb.debugger.HandleCommand(f"""command source -s 0 "{rustlib_etc / 'lldb_commands'}" """)
          '';
        };

        # NOTE: Currently, helix crashes when editing markdown in certain scenarios,
        # presumably due to an old markdown treesitter grammar
        # https://github.com/helix-editor/helix/issues/9011
        # https://github.com/helix-editor/helix/issues/8821
        # https://github.com/tree-sitter-grammars/tree-sitter-markdown/issues/114

        programs.helix = {
          enable = true;
          package = helix.packages.${system}.helix;
          languages = {
            language-server = {
              lexical = {
                command = "lexical";
                args = ["start"];
              };

              # next-ls = {
              #   command = "next-ls";
              #   args = ["--stdout"];
              # };

              # deno = {
              #   command = "deno";
              #   args = ["lsp"];
              #   config = {
              #     enable = true;
              #     lint = true;
              #     unstable = true;
              #   };
              # };
            };

            language = [
              # {
              #   name = "heex";
              #   scope = "source.heex";
              #   injection-regex = "heex";
              #   language-servers = ["lexical"]; # "lexical" "next-ls" ?
              #   auto-format = true;
              #   file-types = ["heex"];
              #   roots = ["mix.exs" "mix.lock"];
              #   indent = {
              #     tab-width = 2;
              #     unit = "  ";
              #   };
              # }
              # {
              #   name = "elixir";
              #   language-servers = ["lexical"]; # "lexical" "next-ls" ?
              #   auto-format = true;
              # }
              {
                name = "rust";

                debugger = {
                  name = "lldb-vscode";
                  transport = "stdio";
                  command = "lldb-vscode";
                  templates = [
                    {
                      name = "binary";
                      request = "launch";
                      completion = [
                        {
                          name = "binary";
                          completion = "filename";
                        }
                      ];
                      args = {
                        program = "{0}";
                        initCommands = ["command script import ${config.xdg.configHome}/lldb_vscode_rustc_primer.py"];
                      };
                    }
                  ];
                };
              }
              {
                name = "html";
                file-types = ["html"];
                scope = "source.html";
                auto-format = false;
              }
              {
                name = "nix";
                file-types = ["nix"];
                scope = "source.nix";
                auto-format = true;
                formatter = {
                  command = "alejandra";
                  args = ["-"];
                };
              }
              {
                name = "fish";
                file-types = ["fish"];
                scope = "source.fish";
                auto-format = true;
                indent = {
                  tab-width = 2;
                  unit = "\t";
                };
              }

              # {
              #   name = "javascript";
              #   language-id = "javascript";
              #   grammar = "javascript";
              #   scope = "source.js";
              #   injection-regex = "^(js|javascript)$";
              #   file-types = ["js" "mjs"];
              #   shebangs = ["deno"];
              #   language-servers = ["deno"];
              #   roots = ["deno.jsonc" "deno.json"];
              #   formatter = {
              #     command = "deno";
              #     args = ["fmt"];
              #   };
              #   auto-format = true;
              #   comment-token = "//";
              #   indent = {
              #     tab-width = 2;
              #     unit = "\t";
              #   };
              # }

              # {
              #   name = "typescript";
              #   language-id = "typescript";
              #   grammar = "typescript";
              #   scope = "source.ts";
              #   injection-regex = "^(ts|typescript)$";
              #   file-types = ["ts"];
              #   shebangs = ["deno"];
              #   language-servers = ["deno"];
              #   roots = ["deno.jsonc" "deno.json"];
              #   formatter = {
              #     command = "deno";
              #     args = ["fmt"];
              #   };
              #   auto-format = true;
              #   comment-token = "//";
              #   indent = {
              #     tab-width = 2;
              #     unit = "\t";
              #   };
              # }

              # {
              #   name = "jsonc";
              #   language-id = "json";
              #   grammar = "jsonc";
              #   scope = "source.jsonc";
              #   injection-regex = "^(jsonc)$";
              #   roots = ["deno.jsonc" "deno.json"];
              #   file-types = ["jsonc"];
              #   language-servers = ["deno"];
              #   indent = {
              #     tab-width = 2;
              #     unit = "  ";
              #   };
              #   auto-format = true;
              # }
            ];
          };

          settings = {
            theme = "custom";

            editor = {
              soft-wrap.enable = true;
              auto-pairs = false;
              # auto-save = false;
              # completion-trigger-len = 1;
              # color-modes = false;
              bufferline = "multiple";
              # scrolloff = 8;
              rulers = [81 121];
              cursorline = true;

              cursor-shape = {
                normal = "block";
                insert = "bar";
                select = "underline";
              };

              file-picker.hidden = false;
              indent-guides = {
                render = true;
                character = "▏";
              };

              lsp = {
                display-messages = true;
                # display-inlay-hints = true;
              };
              statusline = {
                separator = " ";
                mode = {
                  "normal" = "N";
                  "insert" = "I";
                  "select" = "S";
                };
                left = [
                  "file-name"
                  "mode"
                  # "selections"
                  # "primary-selection-length"
                  # "position"
                  # "position-percentage"
                  "spinner"
                  "diagnostics"
                  "workspace-diagnostics"
                ];
              };
              #   center = ["file-name"];
              # right = ["version-control" "total-line-numbers" "file-encoding"];
              # };
            };
            keys = {
              insert = {
                j = {
                  k = "normal_mode";
                  j = "normal_mode";
                  K = "normal_mode";
                  J = "normal_mode";
                };
              };

              normal = {
                "C-k" = "jump_view_up";
                "C-j" = "jump_view_down";
                "C-h" = "jump_view_left";
                "C-l" = "jump_view_right";
                "C-q" = ":quit-all!";
                # "L" = "repeat_last_motion";
                space = {
                  q = ":reflow 80";
                  Q = ":reflow 120";
                  C = ":bc!";
                  h = ":toggle lsp.display-inlay-hints";
                  # O = ["select_textobject_inner WORD", ":pipe-to xargs xdg-open"];
                };
              };

              select = {
                space = {
                  q = ":reflow 80";
                  Q = ":reflow 120";
                };
                # "L" = "repeat_last_motion";
              };
            };
          };

          themes = with colors.withHashPrefix; {
            custom = {
              "type" = orange;

              "constructor" = blue;

              "constant" = orange;
              "constant.builtin" = orange;
              "constant.character" = yellow;
              "constant.character.escape" = orange;

              "string" = green;
              "string.regexp" = orange;
              "string.special" = blue;

              "comment" = {
                fg = fgdim;
                modifiers = ["italic"];
              };

              "variable" = text;
              "variable.parameter" = {
                fg = red;
                modifiers = ["italic"];
              };
              "variable.builtin" = red;
              "variable.other.member" = text;

              "label" = blue;

              "punctuation" = fgdim;
              "punctuation.special" = blue;

              "keyword" = purple;
              "keyword.storage.modifier.ref" = yellow;
              "keyword.control.conditional" = {
                fg = purple;
                modifiers = ["italic"];
              };

              "operator" = blue;

              "function" = blue;
              "function.macro" = purple;

              "tag" = purple;
              "attribute" = blue;

              "namespace" = {
                fg = blue;
                modifiers = ["italic"];
              };

              "special" = blue;

              "markup.heading.marker" = {
                fg = orange;
                modifiers = ["bold"];
              };
              "markup.heading.1" = blue;
              "markup.heading.2" = yellow;
              "markup.heading.3" = green;
              "markup.heading.4" = orange;
              "markup.heading.5" = red;
              "markup.heading.6" = fg3;
              "markup.list" = purple;
              "markup.bold" = {modifiers = ["bold"];};
              "markup.italic" = {modifiers = ["italic"];};
              "markup.strikethrough" = {modifiers = ["crossed_out"];};
              "markup.link.url" = {
                fg = red;
                modifiers = ["underlined"];
              };
              "markup.link.text" = blue;
              "markup.raw" = red;

              "diff.plus" = green;
              "diff.minus" = red;
              "diff.delta" = blue;

              "ui.linenr" = {fg = fgdim;};
              "ui.linenr.selected" = {fg = fg2;};

              "ui.statusline" = {
                fg = fgdim;
                bg = bg;
              };
              "ui.statusline.inactive" = {
                fg = fg3;
                bg = bg2;
              };
              "ui.statusline.normal" = {
                fg = bg;
                bg = purple;
                modifiers = ["bold"];
              };
              "ui.statusline.insert" = {
                fg = bg;
                bg = green;
                modifiers = ["bold"];
              };
              "ui.statusline.select" = {
                fg = bg;
                bg = red;
                modifiers = ["bold"];
              };

              "ui.popup" = {
                fg = text;
                bg = bg2;
              };
              "ui.window" = {fg = fgdim;};
              "ui.help" = {
                fg = fg2;
                bg = bg2;
              };

              "ui.bufferline" = {
                fg = fgdim;
                bg = bg2;
              };
              "ui.bufferline.background" = {bg = bg2;};

              "ui.text" = text;
              "ui.text.focus" = {
                fg = text;
                bg = bg3;
                modifiers = ["bold"];
              };
              "ui.text.inactive" = {fg = fg2;};

              "ui.virtual" = fg2;
              "ui.virtual.ruler" = {bg = bg3;};
              "ui.virtual.indent-guide" = bg3;
              "ui.virtual.inlay-hint" = {
                fg = bg3;
                bg = bg;
              };

              "ui.selection" = {bg = bg5;};

              "ui.cursor" = {
                fg = bg;
                bg = text;
              };
              "ui.cursor.primary" = {
                fg = bg;
                bg = red;
              };
              "ui.cursor.match" = {
                fg = orange;
                modifiers = ["bold"];
              };

              "ui.cursor.primary.normal" = {
                fg = bg;
                bg = text;
              };
              "ui.cursor.primary.insert" = {
                fg = bg;
                bg = text;
              };
              "ui.cursor.primary.select" = {
                fg = bg;
                bg = text;
              };

              "ui.cursor.normal" = {
                fg = bg;
                bg = fg;
              };
              "ui.cursor.insert" = {
                fg = bg;
                bg = fg;
              };
              "ui.cursor.select" = {
                fg = bg;
                bg = fg;
              };

              "ui.cursorline.primary" = {bg = bg3;};

              "ui.highlight" = {
                bg = bg3;
                fg = bg;
                modifiers = ["bold"];
              };

              "ui.menu" = {
                fg = fg3;
                bg = bg2;
              };
              "ui.menu.selected" = {
                fg = text;
                bg = bg3;
                modifiers = ["bold"];
              };

              "diagnostic.error" = {
                underline = {
                  color = red;
                  style = "curl";
                };
              };
              "diagnostic.warning" = {
                underline = {
                  color = orange;
                  style = "curl";
                };
              };
              "diagnostic.info" = {
                underline = {
                  color = blue;
                  style = "curl";
                };
              };
              "diagnostic.hint" = {
                underline = {
                  color = blue;
                  style = "curl";
                };
              };

              error = red;
              warning = orange;
              info = blue;
              hint = yellow;
              "ui.background" = {
                bg = bg;
                fg = fgdim;
              };

              # "ui.cursorline.primary" = { bg = "default" }
              # "ui.cursorline.secondary" = { bg = "default" }
              "ui.cursorcolumn.primary" = {bg = bg3;};
              "ui.cursorcolumn.secondary" = {bg = bg3;};

              "ui.bufferline.active" = {
                fg = primary;
                bg = bg3;
                underline = {
                  color = primary;
                  style = "";
                };
              };
            };
          };
        };
      };

      htop = {
        programs.htop = {
          enable = true;
          settings = {
            #   hide_kernel_threads = 1;
            #   hide_userland_threads = 1;
            #   show_program_path = 0;
            #   header_margin = 0;
            #   show_cpu_frequency = 1;
            #   highlight_base_name = 1;
            #   tree_view = 0;
            # htop_version = "3.2.2";
            # config_reader_min_version = 3;
            fields = "0 48 17 18 38 39 40 2 46 47 49 1";
            hide_kernel_threads = 1;
            hide_userland_threads = 1;
            show_program_path = 0;
            header_margin = 0;
            show_cpu_frequency = 1;
            highlight_base_name = 1;
            tree_view = 0;
            hide_running_in_container = 0;
            shadow_other_users = 0;
            show_thread_names = 0;
            highlight_deleted_exe = 1;
            shadow_distribution_path_prefix = 0;
            highlight_megabytes = 1;
            highlight_threads = 1;
            highlight_changes = 0;
            highlight_changes_delay_secs = 5;
            find_comm_in_cmdline = 1;
            strip_exe_from_cmdline = 1;
            show_merged_command = 0;
            screen_tabs = 1;
            detailed_cpu_time = 0;
            cpu_count_from_one = 0;
            show_cpu_usage = 1;
            show_cpu_temperature = 0;
            degree_fahrenheit = 0;
            update_process_names = 0;
            account_guest_in_cpu_meter = 0;
            enable_mouse = 1;
            delay = 15;
            hide_function_bar = 0;
            header_layout = "two_50_50";
            column_meters_0 = "LeftCPUs Memory Swap";
            column_meter_modes_0 = "1 1 1";
            column_meters_1 = "RightCPUs Tasks LoadAverage Uptime";
            column_meter_modes_1 = "1 2 2 2";
            sort_key = 47;
            tree_sort_key = 0;
            sort_direction = -1;
            tree_sort_direction = 1;
            tree_view_always_by_pid = 0;
            all_branches_collapsed = 0;
            # screen:Main=PID USER PRIORITY NICE M_VIRT M_RESIDENT M_SHARE STATE PERCENT_CPU PERCENT_MEM TIME Command
            # .sort_key=PERCENT_MEM
            # .tree_sort_key=PID
            # .tree_view=0
            # .tree_view_always_by_pid=0
            # .sort_direction=-1
            # .tree_sort_direction=1
            # .all_branches_collapsed=0
            # screen:I/O=PID USER IO_PRIORITY IO_RATE IO_READ_RATE IO_WRITE_RATE Command
            # .sort_key=IO_RATE
            # .tree_sort_key=PID
            # .tree_view=0
            # .tree_view_always_by_pid=0
            # .sort_direction=-1
            # .tree_sort_direction=1
            # .all_branches_collapsed=0
          };
        };
      };

      # hyprland = {};

      iex = {
        home.file.".iex.exs" = {
          enable = true;
          text = ''
            Application.put_env(:elixir, :ansi_enabled, true)

            # PROTIP: to break, `#iex:break`

            IEx.configure(
              colors: [enabled: true],
              inspect: [
                pretty: true,
                printable_limit: :infinity,
                limit: :infinity,
                charlists: :as_lists
              ],
              default_prompt: [
                # ANSI CHA, move cursor to column 1
                # "\e[G",
                :magenta,
                # IEx prompt variable
                "%prefix",
                "#",
                # IEx prompt variable
                "%counter",
                # plain string
                ">",
                :reset
              ]
              |> IO.ANSI.format()
              |> IO.chardata_to_string()
            )
          '';
        };
      };

      # kitty = {};

      linux = {pkgs, ...}: {
        home = {
          sessionVariables = {
            MOZ_ENABLE_WAYLAND = "1";
          };
        };

        programs.fish = {
          shellAliases = {
            disks = "df -h && lsblk";
            sctl = "sudo systemctl";
            bt = "bluetoothctl";
            pa = "pulsemixer";
            sctlu = "systemctl --user";
          };

          functions = {
            pp = ''
              if test (count $argv) -gt 0
                while true; ping -O -i 1 -w 5 -c 10000000 $argv; sleep 1; end
              else
                while true; ping -O -i 1 -w 5 -c 10000000 1.1.1.1; sleep 1; end
              end
            '';
          };
        };

        home.packages = [
          (pkgs.buildEnv {
            name = "my-linux-scripts";
            paths = [./modules/home-manager/scripts/linux];
          })
        ];
      };

      linux-desktop-environment-config = {
        pkgs,
        # font,
        ...
      }: {
        imports = with homeManagerModules; [
          linux
          desktop
          firefox
        ];

        gtk.theme = {
          name = "Catppuccin-Mocha-Compact-Sapphire-Dark";
          package = pkgs.catppuccin-gtk.override {
            accents = ["sapphire"];
            size = "compact";
            tweaks = ["rimless"];
            variant = "mocha";
          };
        };

        home.pointerCursor = {
          name = "Bibata-Modern-Classic";
          package = pkgs.bibata-cursors;
          size = 40; # TODO: this doesn't seem to work -- at least in Sway
          # some icons are also missing (hand2?)
        };
      };

      macos = {
        imports = with homeManagerModules; [
          desktop
          pass
        ];
      };

      # mako = {};

      # nnn = {};

      pass = {pkgs, ...}: {
        programs.password-store = {
          enable = true;
          package = pkgs.pass.withExtensions (exts: [exts.pass-otp]);
        };

        home.packages = with pkgs; [
          pinentry-curses
        ];
      };

      senpai = {config, ...}: {
        programs.senpai = {
          enable = true;
          config = {
            address = "irc+insecure://beefcake:6667";
            nickname = "lytedev";
            password-cmd = ["pass" "soju"];
          };
        };

        home.file."${config.xdg.configHome}/senpai/senpai.scfg" = {
          enable = true;
          text = ''
            address irc+insecure://beefcake:6667
            nickname lytedev
            password-cmd pass soju
          '';
        };
      };

      # sway = {};
      # sway-laptop = {};
      # swaylock = {};
      # tmux = {};
      # wallpaper-manager = {};
      # waybar = {};

      wezterm = {
        pkgs,
        # font,
        ...
      }: {
        # docs: https://wezfurlong.org/wezterm/config/appearance.html#defining-your-own-colors
        programs.wezterm = with colors.withHashPrefix; {
          enable = true;
          extraConfig = builtins.readFile ./modules/home-manager/wezterm/config.lua;
          colorSchemes = {
            catppuccin-mocha-sapphire = {
              ansi = map (x: colors.withHashPrefix.${toString x}) (pkgs.lib.lists.range 0 7);
              brights = map (x: colors.withHashPrefix.${toString (x + 8)}) (pkgs.lib.lists.range 0 7);

              foreground = fg;
              background = bg;

              cursor_fg = bg;
              cursor_bg = text;
              cursor_border = text;

              selection_fg = bg;
              selection_bg = yellow;

              scrollbar_thumb = bg2;

              split = bg5;

              # indexed = { [136] = '#af8700' },
              tab_bar = {
                background = bg3;

                active_tab = {
                  bg_color = primary;
                  fg_color = bg;
                  italic = false;
                };
                inactive_tab = {
                  bg_color = bg2;
                  fg_color = fgdim;
                  italic = false;
                };
                inactive_tab_hover = {
                  bg_color = bg3;
                  fg_color = primary;
                  italic = false;
                };
                new_tab = {
                  bg_color = bg2;
                  fg_color = fgdim;
                  italic = false;
                };
                new_tab_hover = {
                  bg_color = bg3;
                  fg_color = primary;
                  italic = false;
                };
              };

              compose_cursor = orange;

              # copy_mode_active_highlight_bg = { Color = '#000000' },
              # copy_mode_active_highlight_fg = { AnsiColor = 'Black' },
              # copy_mode_inactive_highlight_bg = { Color = '#52ad70' },
              # copy_mode_inactive_highlight_fg = { AnsiColor = 'White' },

              # quick_select_label_bg = { Color = 'peru' },
              # quick_select_label_fg = { Color = '#ffffff' },
              # quick_select_match_bg = { AnsiColor = 'Navy' },
              # quick_select_match_fg = { Color = '#ffffff' },
            };
          };
        };
      };

      zellij = {lib, ...}: {
        # zellij does not support modern terminal keyboard input:
        # https://github.com/zellij-org/zellij/issues/735
        programs.zellij = {
          # uses home manager's toKDL generator
          enable = true;
          # enableFishIntegration = true;
          settings = {
            pane_frames = false;
            simplified_ui = true;
            default_mode = "locked";
            mouse_mode = true;
            copy_clipboard = "primary";
            copy_on_select = true;
            mirror_session = false;

            keybinds = with builtins; let
              binder = bind: let
                keys = elemAt bind 0;
                action = elemAt bind 1;
                argKeys = map (k: "\"${k}\"") (lib.lists.flatten [keys]);
              in {
                name = "bind ${concatStringsSep " " argKeys}";
                value = action;
              };
              layer = binds: (listToAttrs (map binder binds));
            in {
              # _props = {clear-defaults = true;};
              normal = {};
              locked = layer [
                [["Ctrl g"] {SwitchToMode = "Normal";}]
                [["Ctrl L"] {NewPane = "Right";}]
                [["Ctrl Z"] {NewPane = "Right";}]
                [["Ctrl J"] {NewPane = "Down";}]
                [["Ctrl h"] {MoveFocus = "Left";}]
                [["Ctrl l"] {MoveFocus = "Right";}]
                [["Ctrl j"] {MoveFocus = "Down";}]
                [["Ctrl k"] {MoveFocus = "Up";}]
              ];
              resize = layer [
                [["Ctrl n"] {SwitchToMode = "Normal";}]
                [["h" "Left"] {Resize = "Increase Left";}]
                [["j" "Down"] {Resize = "Increase Down";}]
                [["k" "Up"] {Resize = "Increase Up";}]
                [["l" "Right"] {Resize = "Increase Right";}]
                [["H"] {Resize = "Decrease Left";}]
                [["J"] {Resize = "Decrease Down";}]
                [["K"] {Resize = "Decrease Up";}]
                [["L"] {Resize = "Decrease Right";}]
                [["=" "+"] {Resize = "Increase";}]
                [["-"] {Resize = "Decrease";}]
              ];
              pane = layer [
                [["Ctrl p"] {SwitchToMode = "Normal";}]
                [["h" "Left"] {MoveFocus = "Left";}]
                [["l" "Right"] {MoveFocus = "Right";}]
                [["j" "Down"] {MoveFocus = "Down";}]
                [["k" "Up"] {MoveFocus = "Up";}]
                [["p"] {SwitchFocus = [];}]
                [
                  ["n"]
                  {
                    NewPane = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["d"]
                  {
                    NewPane = "Down";
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["r"]
                  {
                    NewPane = "Right";
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["x"]
                  {
                    CloseFocus = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["f"]
                  {
                    ToggleFocusFullscreen = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["z"]
                  {
                    TogglePaneFrames = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["w"]
                  {
                    ToggleFloatingPanes = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["e"]
                  {
                    TogglePaneEmbedOrFloating = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["c"]
                  {
                    SwitchToMode = "RenamePane";
                    PaneNameInput = 0;
                  }
                ]
              ];
              move = layer [
                [["Ctrl h"] {SwitchToMode = "Normal";}]
                [["n" "Tab"] {MovePane = [];}]
                [["p"] {MovePaneBackwards = [];}]
                [["h" "Left"] {MovePane = "Left";}]
                [["j" "Down"] {MovePane = "Down";}]
                [["k" "Up"] {MovePane = "Up";}]
                [["l" "Right"] {MovePane = "Right";}]
              ];
              tab = layer [
                [["Ctrl t"] {SwitchToMode = "Normal";}]
                [
                  ["r"]
                  {
                    SwitchToMode = "RenameTab";
                    TabNameInput = 0;
                  }
                ]
                [["h" "Left" "Up" "k"] {GoToPreviousTab = [];}]
                [["l" "Right" "Down" "j"] {GoToNextTab = [];}]
                [
                  ["n"]
                  {
                    NewTab = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["x"]
                  {
                    CloseTab = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["s"]
                  {
                    ToggleActiveSyncTab = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["1"]
                  {
                    GoToTab = 1;
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["2"]
                  {
                    GoToTab = 2;
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["3"]
                  {
                    GoToTab = 3;
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["4"]
                  {
                    GoToTab = 4;
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["5"]
                  {
                    GoToTab = 5;
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["6"]
                  {
                    GoToTab = 6;
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["7"]
                  {
                    GoToTab = 7;
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["8"]
                  {
                    GoToTab = 8;
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["9"]
                  {
                    GoToTab = 9;
                    SwitchToMode = "Normal";
                  }
                ]
                [["Tab"] {ToggleTab = [];}]
              ];
              scroll = layer [
                [["Ctrl s"] {SwitchToMode = "Normal";}]
                [
                  ["e"]
                  {
                    EditScrollback = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["s"]
                  {
                    SwitchToMode = "EnterSearch";
                    SearchInput = 0;
                  }
                ]
                [
                  ["Ctrl c"]
                  {
                    ScrollToBottom = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [["j" "Down"] {ScrollDown = [];}]
                [["k" "Up"] {ScrollUp = [];}]
                [["Ctrl f" "PageDown" "Right" "l"] {PageScrollDown = [];}]
                [["Ctrl b" "PageUp" "Left" "h"] {PageScrollUp = [];}]
                [["d"] {HalfPageScrollDown = [];}]
                [["u"] {HalfPageScrollUp = [];}]
                # uncomment this and adjust key if using copy_on_select=false
                # bind "Alt c" { Copy; }
              ];
              search = layer [
                [["Ctrl s"] {SwitchToMode = "Normal";}]
                [
                  ["Ctrl c"]
                  {
                    ScrollToBottom = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [["j" "Down"] {ScrollDown = [];}]
                [["k" "Up"] {ScrollUp = [];}]
                [["Ctrl f" "PageDown" "Right" "l"] {PageScrollDown = [];}]
                [["Ctrl b" "PageUp" "Left" "h"] {PageScrollUp = [];}]
                [["d"] {HalfPageScrollDown = [];}]
                [["u"] {HalfPageScrollUp = [];}]
                [["n"] {Search = "down";}]
                [["p"] {Search = "up";}]
                [["c"] {SearchToggleOption = "CaseSensitivity";}]
                [["w"] {SearchToggleOption = "Wrap";}]
                [["o"] {SearchToggleOption = "WholeWord";}]
              ];
              entersearch = layer [
                [["Ctrl c" "Esc"] {SwitchToMode = "Scroll";}]
                [["Enter"] {SwitchToMode = "Search";}]
              ];
              renametab = layer [
                [["Ctrl c"] {SwitchToMode = "Normal";}]
                [
                  ["Esc"]
                  {
                    UndoRenameTab = [];
                    SwitchToMode = "Tab";
                  }
                ]
              ];
              renamepane = layer [
                [["Ctrl c"] {SwitchToMode = "Normal";}]
                [
                  ["Esc"]
                  {
                    UndoRenamePane = [];
                    SwitchToMode = "Pane";
                  }
                ]
              ];
              session = layer [
                [["Ctrl o"] {SwitchToMode = "Normal";}]
                [["Ctrl s"] {SwitchToMode = "Scroll";}]
                [["d"] {Detach = [];}]
              ];
              tmux = layer [
                [["["] {SwitchToMode = "Scroll";}]
                [
                  ["Ctrl b"]
                  {
                    Write = 2;
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["\\\""]
                  {
                    NewPane = "Down";
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["%"]
                  {
                    NewPane = "Right";
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["z"]
                  {
                    ToggleFocusFullscreen = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["c"]
                  {
                    NewTab = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [[","] {SwitchToMode = "RenameTab";}]
                [
                  ["p"]
                  {
                    GoToPreviousTab = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["n"]
                  {
                    GoToNextTab = [];
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["Left"]
                  {
                    MoveFocus = "Left";
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["Right"]
                  {
                    MoveFocus = "Right";
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["Down"]
                  {
                    MoveFocus = "Down";
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["Up"]
                  {
                    MoveFocus = "Up";
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["h"]
                  {
                    MoveFocus = "Left";
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["l"]
                  {
                    MoveFocus = "Right";
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["j"]
                  {
                    MoveFocus = "Down";
                    SwitchToMode = "Normal";
                  }
                ]
                [
                  ["k"]
                  {
                    MoveFocus = "Up";
                    SwitchToMode = "Normal";
                  }
                ]
                [["o"] {FocusNextPane = [];}]
                [["d"] {Detach = [];}]
                [["Space"] {NextSwapLayout = [];}]
                [
                  ["x"]
                  {
                    CloseFocus = [];
                    SwitchToMode = "Normal";
                  }
                ]
              ];
              "shared_except \"locked\"" = layer [
                [["Ctrl g"] {SwitchToMode = "Locked";}]
                [["Ctrl q"] {Quit = [];}]
                [["Alt n"] {NewPane = [];}]
                [["Alt h" "Alt Left"] {MoveFocusOrTab = "Left";}]
                [["Alt l" "Alt Right"] {MoveFocusOrTab = "Right";}]
                [["Alt j" "Alt Down"] {MoveFocus = "Down";}]
                [["Alt k" "Alt Up"] {MoveFocus = "Up";}]
                [["Alt ]" "Alt +"] {Resize = "Increase";}]
                [["Alt -"] {Resize = "Decrease";}]
                [["Alt ["] {PreviousSwapLayout = [];}]
                [["Alt ]"] {NextSwapLayout = [];}]
              ];
              "shared_except \"normal\" \"locked\"" = layer [
                [["Enter" "Esc"] {SwitchToMode = "Normal";}]
              ];
              "shared_except \"pane\" \"locked\"" = layer [
                [["Ctrl p"] {SwitchToMode = "Pane";}]
              ];
              "shared_except \"resize\" \"locked\"" = layer [
                [["Ctrl n"] {SwitchToMode = "Resize";}]
              ];
              "shared_except \"scroll\" \"locked\"" = layer [
                [["Ctrl s"] {SwitchToMode = "Scroll";}]
              ];
              "shared_except \"session\" \"locked\"" = layer [
                [["Ctrl o"] {SwitchToMode = "Session";}]
              ];
              "shared_except \"tab\" \"locked\"" = layer [
                [["Ctrl t"] {SwitchToMode = "Tab";}]
              ];
              "shared_except \"move\" \"locked\"" = layer [
                [["Ctrl h"] {SwitchToMode = "Move";}]
              ];
              "shared_except \"tmux\" \"locked\"" = layer [
                [["Ctrl b"] {SwitchToMode = "Tmux";}]
              ];
            };

            default_layout = "compact";
            theme = "match";

            themes = {
              match = with colors.withHashPrefix; {
                fg = fg;
                bg = bg;

                black = bg;
                white = fg;

                red = red;
                green = green;
                yellow = yellow;
                blue = blue;
                magenta = purple;
                cyan = blue;
                orange = orange;
              };
            };
            # TODO: port config

            plugins = {
              # tab-bar = {path = "tab-bar";};
              # compact-bar = {path = "compact-bar";};
            };

            ui = {
              pane_frames = {
                rounded_corners = true;
                hide_session_name = true;
              };
            };
          };
        };

        home.shellAliases = {
          z = "zellij";
        };
      };
    };

    nixosConfigurations = {
      beefcake = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = with nixosModules; [
          common
          hardware.nixosModules.common-cpu-intel
          fonts
          {
            time = {
              timeZone = "America/Chicago";
            };
          }
          ./nixos/beefcake.nix
          {
            services.smartd.enable = true;
            services.fwupd.enable = true;
          }
        ];
      };

      dragon = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ({
            pkgs,
            lib,
            config,
            ...
          }: {
            system.stateVersion = "24.05";
            networking.hostName = "dragon";

            imports = with nixosModules; [
              common

              outputs.diskoConfigurations.standard
              hardware.nixosModules.common-cpu-amd
              hardware.nixosModules.common-pc-ssd

              {
                hardware.opengl.extraPackages = [
                  # pkgs.rocmPackages.clr.icd
                  pkgs.amdvlk

                  # encoding/decoding acceleration
                  pkgs.libvdpau-va-gl
                  pkgs.vaapiVdpau
                ];
              }

              wifi
              graphical-workstation
              music-production
              gaming
              slippi.nixosModules.default
              {
                # dragon hardware
                boot.loader.efi.canTouchEfiVariables = true;
                boot.loader.systemd-boot.enable = true;
                boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "ahci" "usbhid"];
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
                    web-dev-lan = 18888;
                    ports = [
                      terraria
                      stardew-valley
                      web-dev-lan
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
              imports = with homeManagerModules; [
                pass
                senpai
                iex
                cargo
                firefox-no-tabs
                linux-desktop-environment-config
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
          })
          {
            services.smartd.enable = true;
            services.fwupd.enable = true;
          }
        ];
      };

      foxtrot = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = with nixosModules; [
          common
          ./nixos/foxtrot.nix
          {
            services.smartd.enable = true;
            services.fwupd.enable = true;
          }
        ];
      };

      thablet = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = with nixosModules; [
          common
          ./nixos/thablet.nix
          {
            services.smartd.enable = true;
            services.fwupd.enable = true;
          }
        ];
      };

      thinker = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = with nixosModules; [
          common
          ./nixos/thinker.nix
          {
            services.smartd.enable = true;
            services.fwupd.enable = true;
          }
        ];
      };

      rascal = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = with nixosModules; [
          common
          ./nixos/rascal.nix
          {
            services.smartd.enable = true;
            services.fwupd.enable = true;
          }
        ];
      };
    };

    # TODO: homeconfigs?
    # homeConfigurations = {
    #   # TODO: non-system-specific home configurations?
    #   "deck" = let
    #     system = "x86_64-linux";
    #   in
    #     home-manager.lib.homeManagerConfiguration {
    #       pkgs = pkgsFor system;
    #       extraSpecialArgs = moduleArgs;
    #       modules = with homeManagerModules; [
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
    #       modules = with homeManagerModules; [
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
