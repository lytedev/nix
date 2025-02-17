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
  ];

  config = {
    nixpkgs = {
      config.allowUnfree = lib.mkDefault true;
      overlays = [ self.flakeLib.forSelfOverlay ];
    };
    nix = {
      nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
      # registry = lib.mapAttrs (_: value: { flake = value; }) self.inputs;

      settings = {
        trusted-users = lib.mkDefault [ "@wheel" ];
        extra-experimental-features = lib.mkDefault [
          "nix-command"
          "flakes"
        ];
        auto-optimise-store = lib.mkDefault true;
      };
    };

    sops = {
      age = {
        sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];
        keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
        generateKey = lib.mkDefault true;
      };
    };

    # TODO: for each non-system user on the machine?
    # home-manager = {

    #   useGlobalPkgs = lib.mkDefault true;
    #   backupFileExtension = lib.mkDefault "hm-backup";

    #   sharedModules = with self.outputs.homeManagerModules; [
    #     default
    #   ];

    #   users = {
    #     root = {
    #       home.stateVersion = lib.mkDefault config.system.stateVersion;
    #       # imports = with self.outputs.homeManagerModules; [
    #       # ];
    #     };
    #     daniel = {
    #       home.stateVersion = lib.mkDefault config.system.stateVersion;
    #       imports = with self.outputs.homeManagerModules; [
    #         daniel
    #       ];
    #     };
    #   };
    # };

    systemd.services.nix-daemon.environment.TMPDIR = lib.mkDefault "/var/tmp"; # TODO: why did I do this again?
    boot.tmp.cleanOnBoot = lib.mkDefault true;
    programs.gnupg.agent.enable = lib.mkDefault true;
    time.timeZone = lib.mkDefault "America/Chicago";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    hardware.enableRedistributableFirmware = lib.mkDefault true;

    users.users.root = {
      openssh.authorizedKeys.keys = lib.mkDefault [ self.outputs.pubkey ];
      shell = lib.mkIf config.lyte.shell.enable pkgs.fish;
    };

    services = {
      openssh = {
        enable = lib.mkDefault true;

        settings = {
          PasswordAuthentication = lib.mkDefault false;
          KbdInteractiveAuthentication = lib.mkDefault false;
          PermitRootLogin = lib.mkForce "prohibit-password";
        };

        openFirewall = lib.mkDefault true;

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
      fwupd.enable = lib.mkDefault true;
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
        "kvm"
      ];
      packages = [ ];
    };
    home-manager.users.daniel = {
      home.stateVersion = lib.mkDefault config.system.stateVersion;
      imports = with self.outputs.homeManagerModules; [
        default
      ];
    };
  };
}
