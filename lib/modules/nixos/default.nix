{ self, ... }:
let
  inherit (self) outputs;
  inherit (outputs)
    nixosModules
    # overlays
    pubkey
    ;
in
{
  common = {
    imports = with nixosModules; [
      deno-netlify-ddns-client
      shell-defaults-and-applications
      desktop
      wifi
      printing
      podman
      virtual-machines
      postgres
      gaming
      gnome
      daniel
      root
    ];
  };

  nix-config = (import ../../../flake.nix).nixConfig;
  shell-defaults-and-applications = import ./shell-config.nix;
  deno-netlify-ddns-client = import ./deno-netlify-ddns-client.nix;

  # boot.tmp.useTmpfs = true;
  # boot.uki.tries = 3;
  # services.irqbalance.enable = true;

  remote-disk-key-entry-on-boot =
    {
      lib,
      pkgs,
      ...
    }:
    {
      /*
        https://nixos.wiki/wiki/Remote_disk_unlocking
        "When using DHCP, make sure your computer is always attached to the network and is able to get an IP adress, or the boot process will hang."
        ^ seems less than ideal
      */
      boot.kernelParams = [ "ip=dhcp" ];
      boot.initrd = {
        # availableKernelModules = ["r8169"]; # ethernet drivers
        systemd.users.root.shell = "/bin/cryptsetup-askpass";
        network = {
          enable = true;
          ssh = {
            enable = true;
            port = 22;
            authorizedKeys = [ pubkey ];
            hostKeys = [ "/etc/secrets/initrd/ssh_host_rsa_key" ];
          };
        };
      };
    };

  laptop =
    # TODO: modularize
    { pkgs, ... }:
    {
      imports = with nixosModules; [
        family-users
        wifi
      ];

      environment.systemPackages = with pkgs; [
        acpi
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
          KillUserProcesses=no
          HandlePowerKey=suspend
          HandlePowerKeyLongPress=poweroff
          HandleRebootKey=reboot
          HandleRebootKeyLongPress=poweroff
          HandleSuspendKey=suspend
          HandleSuspendKeyLongPress=hibernate
          HandleHibernateKey=hibernate
          HandleHibernateKeyLongPress=ignore
          HandleLidSwitch=suspend
          HandleLidSwitchExternalPower=suspend
          HandleLidSwitchDocked=suspend
          HandleLidSwitchDocked=suspend
          IdleActionSec=11m
          IdleAction=ignore
        '';
      };
    };

  gnome =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      config = lib.mkIf config.services.xserver.desktopManager.gnome.enable {

        services = {
          xserver = {
            enable = true;
            displayManager.gdm.enable = true;
            # desktopManager.gnome.enable = true;
          };
          udev.packages = [ pkgs.gnome-settings-daemon ];
        };

        environment = {
          variables.GSK_RENDERER = "gl";
          systemPackages = with pkgs; [
            bitwarden
            # adwaita-gtk-theme
            papirus-icon-theme
            adwaita-icon-theme
            adwaita-icon-theme-legacy
            hydrapaper
          ];
        };

        programs.kdeconnect = {
          enable = true;
          package = pkgs.gnomeExtensions.gsconnect;
        };

        networking.firewall = rec {
          allowedTCPPortRanges = [
            {
              from = 1714;
              to = 1764;
            }
          ];
          allowedUDPPortRanges = allowedTCPPortRanges;
        };
      };
    };

  radio-tools =
    { pkgs, ... }:
    {
      environment = {
        systemPackages = with pkgs; [
          chirp
        ];
      };
    };

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

  fonts =
    { pkgs, ... }:
    {
      fonts.packages = [
        (
          # allow nixpkgs 24.11 and unstable to both work
          if builtins.hasAttr "nerd-fonts" pkgs then
            (pkgs.nerd-fonts.symbols-only)
          else
            (pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
        )
        pkgs.iosevkaLyteTerm
      ];
    };

  plasma6 =
    {
      pkgs,
      lib,
      ...
    }:
    {
      imports = with nixosModules; [
        kde-connect
        pipewire
      ];

      services.xserver.enable = true;

      services.displayManager.sddm = {
        enable = true;
        # package = lib.mkForce pkgs.kdePackages.sddm;
        settings = { };
        # theme = "";
        enableHidpi = true;
        wayland = {
          enable = true;
          compositor = "weston";
        };
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

      programs.gnupg.agent.pinentryPackage = lib.mkForce pkgs.pinentry-qt;
    };

  lutris =
    { pkgs, ... }:
    {
      environment = {
        systemPackages = with pkgs; [
          wineWowPackages.waylandFull
          lutris
          winetricks
        ];
      };
    };

  gaming =
    { pkgs, ... }:
    {
      imports = with nixosModules; [
        # lutris # use the flatpak
        steam # TODO: use the flatpak?
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
          "bluez5.roles" = [
            "hsp_hs"
            "hsp_ag"
            "hfp_hf"
            "hfp_ag"
          ];
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

  podman =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      config = lib.mkIf config.virtualisation.podman.enable {
        environment = {
          systemPackages = with pkgs; [
            podman-compose
          ];
        };

        virtualisation = {
          podman = {
            dockerCompat = config.virtualisation.podman.enable;
            dockerSocket.enable = true;
            defaultNetwork.settings.dns_enabled = true;
          };

          oci-containers = {
            backend = "podman";
          };
        };

        networking = {
          extraHosts = ''
            127.0.0.1 host.docker.internal
            ::1 host.docker.internal
            127.0.0.1 host.containers.internal
            ::1 host.containers.internal
          '';
        };
      };
    };

  virtual-machines =
    {
      lib,
      config,
      ...
    }:
    {
      config = lib.mkIf config.virtualisation.libvirtd.enable {
        users.users.daniel.extraGroups = [ "libvirtd" ];
      };
    };

  postgres =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      config = lib.mkIf config.services.postgresql.enable {
        # this is really just for development usage
        services.postgresql = {
          ensureDatabases = [ "daniel" ];
          ensureUsers = [
            {
              name = "daniel";
              ensureDBOwnership = true;
            }
          ];
          # enableTCPIP = true;
          # package = pkgs.postgresql_15;

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
    };

  desktop =
    {
      pkgs,
      lib,
      config,
      options,
      ...
    }:
    let
      cfg = config.lyte.desktop;
    in
    {
      options = {
        lyte = {
          desktop = {
            enable = lib.mkEnableOption "Enable my default desktop configuration and applications";
          };
        };
      };
      config = lib.mkIf cfg.enable {
        services.xserver.desktopManager.gnome.enable = true;

        xdg.portal.enable = true;

        hardware =
          if builtins.hasAttr "graphics" options.hardware then
            {
              graphics = {
                enable = true;
                # enable32Bit = true;
                /*
                  driSupport32Bit = true;
                  driSupport = true;
                */
              };
            }
          else
            {
              opengl = {
                enable = true;
                # driSupport32Bit = true;
                driSupport = true;
              };
            };
        fonts.packages = [
          (
            # allow nixpkgs 24.11 and unstable to both work
            if builtins.hasAttr "nerd-fonts" pkgs then
              (pkgs.nerd-fonts.symbols-only)
            else
              (pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; })
          )
          pkgs.iosevkaLyteTerm
        ];
        services.flatpak.enable = true;
        programs.appimage.binfmt = true;
        services.printing.enable = true;
        programs.virt-manager.enable = config.virtualisation.libvirtd.enable;
      };
    };

  printing =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      config = lib.mkIf config.services.printing.enable {
        services.printing.browsing = true;
        services.printing.browsedConf = ''
          BrowseDNSSDSubTypes _cups,_print
          BrowseLocalProtocols all
          BrowseRemoteProtocols all
          CreateIPPPrinterQueues All

          BrowseProtocols all
        '';
        services.printing.drivers = [ pkgs.gutenprint ];
      };
    };

  wifi =
    {
      lib,
      config,
      ...
    }:
    let
      inherit (lib) mkDefault;
      cfg = config.networking.wifi;
    in
    {
      options = {
        networking.wifi.enable = lib.mkEnableOption "Enable wifi via NetworkManager";
      };
      config = lib.mkIf cfg.enable {
        networking.networkmanager = {
          enable = true;
          # ensureProfiles = {
          #   profiles = {
          #     home-wifi = {
          #     id="home-wifi";
          #     permissions = "";
          #     type = "wifi";
          #     };
          #     wifi = {
          #     ssid = "";
          #     };
          #     wifi-security = {
          #     # auth-alg = "";
          #     # key-mgmt = "";
          #     psk = "";
          #     };
          #   };
          # };
        };
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
    };

  steam =
    { pkgs, options, ... }:
    {
      programs.gamescope.enable = true;

      services.pipewire = {
        alsa.support32Bit = true;
      };

      programs.steam = {
        enable = true;

        extest.enable = true;
        gamescopeSession.enable = true;

        extraPackages = with pkgs; [
          gamescope
        ];

        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];

        localNetworkGameTransfers.openFirewall = true;
        remotePlay.openFirewall = true;
      };

      hardware =
        (
          if builtins.hasAttr "graphics" options.hardware then
            {
              graphics = {
                enable = true;
                enable32Bit = true;
              };
            }
          else
            {
              opengl = {
                enable = true;
                driSupport32Bit = true;
              };
            }
        )
        // {
          steam-hardware.enable = true;
        };

      services.udev.packages = with pkgs; [ steam ];

      environment.systemPackages = with pkgs; [
        dualsensectl # for interfacing with dualsense controllers programmatically
      ];

      # remote play ports - should be unnecessary due to programs.steam.remotePlay.openFirewall = true;
      /*
        networking.firewall.allowedUDPPortRanges = [ { from = 27031; to = 27036; } ];
        networking.firewall.allowedTCPPortRanges = [ { from = 27036; to = 27037; } ];
      */
    };

  root =
    {
      pkgs,
      lib,
      ...
    }:
    {
      users.users.root = {
        home = "/root";
        createHome = true;
        openssh.authorizedKeys.keys = [ pubkey ];
        shell = lib.mkForce pkgs.fish;
      };
    };

  daniel =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      users.groups.daniel = { };
      users.users.daniel = {
        isNormalUser = true;
        home = "/home/daniel/.home";
        description = "Daniel Flanagan";
        createHome = true;
        openssh.authorizedKeys.keys = [ pubkey ];
        group = "daniel";
        extraGroups = [
          "users"
          "wheel"
          "video"
          "dialout"
          "uucp"
          "kvm"
        ];
        packages = [ ];
      };
    };
}
