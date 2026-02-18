{
  sops-nix,
  disko,
  slippi,
  jovian,
  self,
  ...
}:
{
  modulesPath,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = with self.outputs.nixosModules; [
    (modulesPath + "/installer/scan/not-detected.nix")
    sops-nix.nixosModules.sops
    disko.nixosModules.disko
    slippi.nixosModules.default
    deno-netlify-ddns-client
    shell-defaults-and-applications
    desktop
    gnome
    cosmic
    niri
    plasma
    wifi
    printing
    podman
    virtual-machines
    postgres
    gaming
    restic
    router
    kanidm
    headscale-server
    laptop
    mobile
    music-production
    earlyoom
    user-env
    claude
    push-to-talk

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

        # Flanfam gets basic dotfile symlinks via activation script
        system.userActivationScripts.flanfamEnv = {
          text = ''
            if [ "$(id -un)" = "flanfam" ]; then
              FLAKE="${config.lyte.flakePath}"
              HOME_DIR="/home/flanfam"

              # Basic shell config symlinks
              mkdir -p "$HOME_DIR/.config/fish/functions"
              mkdir -p "$HOME_DIR/.config/fish/conf.d"
              mkdir -p "$HOME_DIR/.config/helix"
              mkdir -p "$HOME_DIR/.config/atuin"
              mkdir -p "$HOME_DIR/.config/bat"

              ln -sfT "$FLAKE/dotfiles/fish/functions/d.fish" "$HOME_DIR/.config/fish/functions/d.fish"
              ln -sfT "$FLAKE/dotfiles/fish/functions/c.fish" "$HOME_DIR/.config/fish/functions/c.fish"
              ln -sfT "$FLAKE/dotfiles/fish/functions/ltl.fish" "$HOME_DIR/.config/fish/functions/ltl.fish"
              ln -sfT "$FLAKE/dotfiles/fish/conf.d/aliases.fish" "$HOME_DIR/.config/fish/conf.d/aliases.fish"
              ln -sfT "$FLAKE/dotfiles/helix" "$HOME_DIR/.config/helix"
              ln -sfT "$FLAKE/dotfiles/atuin/config.toml" "$HOME_DIR/.config/atuin/config.toml"
              ln -sfT "$FLAKE/dotfiles/bat/config" "$HOME_DIR/.config/bat/config"

              # Face icon
              ${pkgs.curl}/bin/curl -sfo "$HOME_DIR/.face" "https://lyte.dev/icon.png" 2>/dev/null || true
            fi
          '';
        };
      }
    )

    (
      { config, ... }:
      lib.mkIf config.prevent-suspend.enable {
        systemd.targets.sleep.enable = false;
        systemd.targets.suspend.enable = false;
        systemd.targets.hibernate.enable = false;
        systemd.targets.hybrid-sleep.enable = false;
      }
    )

  ];

  options = {
    family-account = {
      enable = lib.mkEnableOption "Enable a user account for family members";
    };
    prevent-suspend = {
      enable = lib.mkEnableOption "Ensure the host does not suspend";
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

      settings = {
        trusted-users = [
          "@wheel"
        ];
        accept-flake-config = true;
        auto-optimise-store = lib.mkDefault true;
      }
      // ((import ../../../flake.nix).nixConfig);
    };

    sops = {
      age = {
        sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];
        keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
        generateKey = lib.mkDefault true;
      };
    };

    systemd.services.nix-daemon.environment.TMPDIR = lib.mkDefault "/var/tmp";
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
          PermitEmptyPasswords = false;
          GSSAPIAuthentication = false;
          KerberosAuthentication = false;
        };

        openFirewall = true;
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
        options = lib.mkDefault "ctrl:nocaps";
      };
      smartd.enable = lib.mkDefault true;
    };

    # Allow input group to access /dev/uinput (needed for ydotool)
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660"
    '';

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
        "power"
        "kvm"
        "input"
      ];
      packages = [ ];
    };

    # Daniel's face icon (for display managers)
    lyte.userSymlinks.".face" = toString (
      builtins.fetchurl {
        url = "https://lyte.dev/img/avatar3-square-512.png";
        sha256 = "sha256:15zwbwisrc01m7ad684rsyq19wl4s33ry9xmgzmi88k1myxhs93x";
      }
    );
  };
}
