{
  sops-nix,
  disko,
  slippi,
  self,
  ...
}:
{
  home-manager,
  modulesPath,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = with self.outputs.nixosModules; [
    (modulesPath + "/installer/scan/not-detected.nix")
    home-manager.nixosModules.home-manager
    sops-nix.nixosModules.sops
    disko.nixosModules.disko
    slippi.nixosModules.default
    deno-netlify-ddns-client
    shell-defaults-and-applications
    desktop
    gnome
    wifi
    printing
    podman
    virtual-machines
    postgres
    gaming
    restic
    router
    kanidm
    laptop

    (
      { config, ... }:
      lib.mkIf config.family-account.enable {
        users.groups.flanfam = { };
        users.users.flanfam = {
          isNormalUser = true;
          home = "/home/flanfam";
          description = "Flanagan Family";
          createHome = true;
          openssh.authorizedKeys.keys = [ self.outputs.pubkey ];
          group = "flanfam";
          shell = lib.mkIf config.lyte.shell.enable pkgs.fish;
          extraGroups = [
            "users"
            "power"
            "video"
          ];
        };
        home-manager.users.flanfam = {
          lyte.shell.enable = lib.mkDefault true;
          lyte.desktop.enable = lib.mkDefault true;
          accounts.email.accounts.primary = {
            primary = true;
            address = "home@lyte.dev";
          };
          home = {
            username = "flanfam";
            homeDirectory = "/home/flanfam";
            stateVersion = lib.mkDefault config.system.stateVersion;
            file.".face" = {
              enable = true;
              source = builtins.fetchurl {
                url = "https://lyte.dev/icon.png";
                sha256 = "sha256:0nf22gwasc64yc5317d0k0api0fwyrf4g3wxljdi2p3ki079ky53";
              };
            };
          };
          imports = with self.outputs.homeManagerModules; [
            {
              _module.args.fullName = config.users.users.flanfam.description;
            }
            default
          ];
        };
      }
    )
  ];

  options = {
    family-account = {
      enable = lib.mkEnableOption "Enable a user account for family members";
    };
  };

  config = {
    system.configurationRevision = toString (
      self.shortRev or self.dirtyShortRev or self.lastModified or "unknown"
    );
    environment = {
      etc = {
        "lytedev/rev".text = config.system.configurationRevision;
        "lytedev/lastModified".text = toString (self.lastModified or "unknown");
      };
    };

    lyte.shell.enable = lib.mkDefault true;
    nixpkgs = {
      config.allowUnfree = lib.mkDefault true;
      overlays = [ self.flakeLib.forSelfOverlay ];
    };
    nix = {
      nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
      # registry = lib.mapAttrs (_: value: { flake = value; }) self.inputs;

      settings = {
        trusted-users = [
          "@wheel"
        ];
        auto-optimise-store = lib.mkDefault true;
      } // ((import ../../../flake.nix).nixConfig);
    };

    sops = {
      age = {
        sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];
        keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
        generateKey = lib.mkDefault true;
      };
    };

    # TODO: for each non-system user on the machine?
    home-manager = {
      useGlobalPkgs = lib.mkDefault true;
      useUserPackages = lib.mkDefault true;
      backupFileExtension = lib.mkDefault "hm-backup";
    };

    systemd.services.nix-daemon.environment.TMPDIR = lib.mkDefault "/var/tmp"; # TODO: why did I do this again?
    boot.tmp.cleanOnBoot = lib.mkDefault true;
    programs.gnupg.agent.enable = lib.mkDefault true;
    time.timeZone = lib.mkDefault "America/Chicago";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    hardware.enableRedistributableFirmware = lib.mkDefault true;

    users.users.root = {
      openssh.authorizedKeys.keys = [ self.outputs.pubkey ];
      shell = lib.mkIf config.lyte.shell.enable pkgs.fish;
    };

    services = {
      openssh = {
        enable = true;

        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "prohibit-password";
        };

        openFirewall = true;

        /*
          listenAddresses = [
            { addr = "0.0.0.0"; port = 22; }
          ];
        */
      };
      avahi = {
        enable = lib.mkDefault true;
        reflector = lib.mkDefault true;
        openFirewall = lib.mkDefault true;
        nssmdns4 = lib.mkDefault true;
      };
      tailscale = {
        enable = lib.mkDefault true;
        useRoutingFeatures = lib.mkDefault "client";
      };
      journald.extraConfig = lib.mkDefault "SystemMaxUse=1G";
      xserver.xkb = {
        layout = lib.mkDefault "us";

        # have the caps-lock key instead be a ctrl key
        options = lib.mkDefault "ctrl:nocaps";
      };
      smartd.enable = lib.mkDefault true;
    };

    console = {
      useXkbConfig = lib.mkDefault true;
      earlySetup = lib.mkDefault true;

      colors =
        with self.outputs.style.colors;
        lib.mkDefault [
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
      hostName = lib.mkDefault "set-a-hostname-dingus";

      useDHCP = lib.mkDefault true;
      firewall = {
        enable = lib.mkDefault true;
        allowPing = lib.mkDefault true;
      };
    };

    users.groups.daniel = { };
    users.users.daniel = {
      isNormalUser = true;
      home = "/home/daniel/.home";
      # TODO: chown /home/daniel
      description = "Daniel Flanagan";
      createHome = true;
      openssh.authorizedKeys.keys = [ self.outputs.pubkey ];
      group = "daniel";
      shell = lib.mkIf config.lyte.shell.enable pkgs.fish;
      extraGroups = [
        "users"
        "wheel"
        "video"
        "dialout"
        "uucp"
        "power"
        "kvm"
      ];
      packages = [ ];
    };
    home-manager.users.daniel = {
      home = {
        stateVersion = lib.mkDefault config.system.stateVersion;
        file.".face" = {
          enable = config.home-manager.users.daniel.lyte.desktop.enable;
          source = builtins.fetchurl {
            url = "https://lyte.dev/img/avatar3-square-512.png";
            sha256 = "sha256:15zwbwisrc01m7ad684rsyq19wl4s33ry9xmgzmi88k1myxhs93x";
          };
        };
      };
      imports = with self.outputs.homeManagerModules; [
        {
          _module.args.fullName = config.users.users.daniel.description;
        }
        default
        daniel
      ];
    };
  };
}
