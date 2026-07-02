{
  sops-nix,
  disko,
  slippi,
  # jovian,
  self,
  ...
}:
{
  modulesPath,
  lib,
  config,
  options,
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
    dns-zones
    dns-server
    dns-updater
    shell-defaults-and-applications
    desktop
    gnome
    cosmic
    niri
    plasma
    greeter
    wifi
    printing
    podman
    k3s
    virtual-machines
    postgres
    gaming
    restic
    router
    kanidm
    kanidm-migrations
    kanidm-oauth2-secrets
    headscale-server
    laptop
    mobile
    music-production
    squeezelite
    tv-player
    earlyoom
    user-env
    claude
    # push-to-talk removed — replacing with telly-spelly or similar
    syncthing
    server
    roms

    (
      { config, ... }:
      lib.mkIf config.lyte.family-account.enable {
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
              FLAKE="${config.lyte.resolvedFlakePath}"
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

        # The family user predates the home-manager removal and was never fully
        # migrated: ~flanfam/.config/niri is a stale home-manager symlink (→ an old
        # hm_niri config), and now that Plasma is off fleet-wide (niri-only) that
        # stale config is what flanfam actually runs. flanfamEnv above can't fix it —
        # it only runs on flanfam login (this device auto-boots to a greeter, flanfam
        # rarely has a live session at deploy) and its `ln -sfT` silently fails
        # against home-manager's leftover real dirs.
        #
        # So provision niri here at DEPLOY time, as root (no flanfam session needed).
        # Make ~/.config/niri a REAL dir so DMS's generated dms/ can live beside the
        # symlinked config.kdl, and point config.kdl at the store (deterministic —
        # every deploy re-points it to the config that was built). config.kdl's own
        # includes are all `optional` and resolved from /etc/niri, so config.kdl is
        # the only file the family user needs.
        system.activationScripts.flanfamNiri = ''
          if [ -d /home/flanfam ]; then
            d=/home/flanfam/.config/niri
            [ -L "$d" ] && rm -f "$d"
            install -d -o flanfam -g flanfam -m 0755 /home/flanfam/.config "$d"
            ln -sfn ${../../../dotfiles/niri/config.kdl} "$d/config.kdl"
            chown -h flanfam:flanfam "$d/config.kdl"
          fi
        '';
      }
    )

    (
      { config, ... }:
      lib.mkIf config.lyte.prevent-suspend.enable {
        systemd.targets.sleep.enable = false;
        systemd.targets.suspend.enable = false;
        systemd.targets.hibernate.enable = false;
        systemd.targets.hybrid-sleep.enable = false;
      }
    )

  ];

  options = {
    hardwareModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of nixos-hardware module names to import (e.g. \"lenovo-thinkpad-t480\").";
    };
    diskConfig = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.either lib.types.str (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Name of the diskoConfiguration to import.";
              };
              params = lib.mkOption {
                type = lib.types.attrs;
                default = { };
                description = "Parameters to pass to the diskoConfiguration function.";
              };
            };
          }
        )
      );
      default = null;
      description = ''
        Disko configuration to import. Either a plain string name for configs
        that are plain attrsets (e.g. "thinker"), or { name, params } for
        configs that are functions (e.g. { name = "unencrypted"; params = { disk = "/dev/nvme0n1"; }; }).
      '';
    };
    lyte.gpu = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "intel"
          "amd"
        ]
      );
      default = null;
      description = "GPU vendor for graphics driver configuration (intel or amd).";
    };
    lyte.family-account = {
      enable = lib.mkEnableOption "Enable a user account for family members";
    };
    lyte.prevent-suspend = {
      enable = lib.mkEnableOption "Ensure the host does not suspend";
    };
  };

  config = {
    system.configurationRevision = toString (
      self.shortRev or self.dirtyShortRev or self.lastModified or "unknown"
    );

    lyte.flakeStorePath = "${self}";
    lyte.shell.enable = lib.mkDefault true;
    nixpkgs = {
      config.allowUnfree = lib.mkDefault true;
      overlays = [ self.flakeLib.forSelfOverlay ];
    };
    nix = {
      nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") (
        lib.filterAttrs (_: value: value ? to && value.to ? path) config.nix.registry
      );

      settings = {
        trusted-users = [
          "@wheel"
        ];
        accept-flake-config = true;
        auto-optimise-store = lib.mkDefault true;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
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

    # Ensure /nix is world-readable and /home/<user> exists with correct
    # ownership — btrfs subvolumes default to 700 root:root, and some
    # services create .config before the user logs in.
    systemd.tmpfiles.rules = [
      "d /nix 0755 root root -"
      "d ${config.lyte.userHome} 0755 ${config.lyte.username} ${config.lyte.username} -"
      "d ${config.lyte.userHome}/.config 0755 ${config.lyte.username} ${config.lyte.username} -"
    ];

    # Various systemd subsystems (accounts-daemon, logind, tmpfiles,
    # sysusers) call `disable_nscd()` during early boot, which sends
    # SIGTERM to nscd.service. Restart=always brings it back up, but on
    # desktop hosts the kill/restart cycles are fast enough to trip
    # systemd's default StartLimitBurst=5/10s and leave nscd in a failed
    # state — which then breaks all kanidm NSS lookups for the rest of
    # the boot. Relax the limit so bursty early-boot invalidations
    # don't wedge it.
    systemd.services.nscd.startLimitBurst = 30;
    systemd.services.nscd.startLimitIntervalSec = 60;
    systemd.services.nix-daemon.environment.TMPDIR = lib.mkDefault "/var/tmp";
    boot.tmp.cleanOnBoot = lib.mkDefault true;
    programs.gnupg.agent.enable = lib.mkDefault true;
    time.timeZone = lib.mkDefault "America/Chicago";
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
    i18n.supportedLocales = lib.mkDefault [
      "en_US.UTF-8/UTF-8"
    ];
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

    # Primary user declared locally in NixOS. Kanidm (when configured)
    # can still handle PAM auth and SSH keys at runtime, but identity
    # (uid/gid/home) lives here so stage-2 activation, sops secret
    # ownership, systemd-tmpfiles rules, and services with User=daniel
    # all resolve without depending on kanidm-unixd being up.
    users.groups.daniel = { };
    users.users.${config.lyte.username} = {
      isNormalUser = true;
      uid = 1000;
      description = "Daniel Flanagan";
      home = config.lyte.userHome;
      group = config.lyte.username;
      shell = lib.mkIf config.lyte.shell.enable pkgs.fish;
      openssh.authorizedKeys.keys = config.lyte.userSshKeys;
      extraGroups = [
        "wheel"
        "video"
        "dialout"
        "uucp"
        "power"
        "kvm"
        "input"
        "users"
        "networkmanager"
      ];
    };

    lyte.userSshKeys = [ self.outputs.pubkey ];

    # Grant kanidm's "administrators" group wheel-equivalent sudo when
    # kanidm-unixd is providing group membership at runtime. No-op when
    # kanidm isn't configured.
    security.sudo.extraRules = [
      {
        groups = [ "administrators" ];
        commands = [
          {
            command = "ALL";
            options = [ "SETENV" ];
          }
        ];
      }
    ];

    # the kanidm PAM stuff currently interferes with my nix-provisioned users
    # TODO: reconcile the config so it doesn't but still allows PAM auth?
    # services.kanidm.client.enable was renamed from services.kanidm.enableClient
    # in nixpkgs unstable. Use optionalAttrs (not mkIf) so the option PATH is
    # absent entirely on hosts where it doesn't exist — mkIf still validates
    # the path against the option tree even when the condition is false.
    services.kanidm =
      (lib.optionalAttrs (options.services ? kanidm && options.services.kanidm ? client) {
        client.enable = lib.mkForce false;
      })
      // (lib.optionalAttrs (options.services ? kanidm && options.services.kanidm ? enableClient) {
        enableClient = lib.mkForce false;
      });

    # Daniel's face icon (for display managers)
    lyte.userSymlinks.".face" = toString (
      builtins.fetchurl {
        url = "https://lyte.dev/img/avatar3-square-512.png";
        sha256 = "sha256:15zwbwisrc01m7ad684rsyq19wl4s33ry9xmgzmi88k1myxhs93x";
      }
    );
  };
}
