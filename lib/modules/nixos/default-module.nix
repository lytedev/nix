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
    dns-zones
    dns-server
    dns-updater
    shell-defaults-and-applications
    desktop
    gnome
    cosmic
    niri
    plasma
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
    earlyoom
    user-env
    claude
    # push-to-talk removed — replacing with telly-spelly or similar
    opencode
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
    # services create .config before the user logs in. `daniel` is a
    # kanidm-provided NSS entry; the tmpfiles rule resolves the name via
    # NSS at activation time.
    systemd.tmpfiles.rules = [
      "d /nix 0755 root root -"
      "d ${config.lyte.userHome} 0755 ${config.lyte.username} ${config.lyte.username} -"
      "d ${config.lyte.userHome}/.config 0755 ${config.lyte.username} ${config.lyte.username} -"
    ];

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

    # Primary user (daniel) is now provided exclusively by kanidm — no
    # local `users.users.<name>` declaration. Authentication, uid/gid,
    # and group memberships come from kanidm via NSS/PAM.

    lyte.userSshKeys = [ self.outputs.pubkey ];

    # Break-glass SSH keys on local filesystem. sshd's AuthorizedKeysFile
    # includes /etc/ssh/authorized_keys.d/%u, so these authorize login
    # even if kanidm-unixd is down.
    environment.etc."ssh/authorized_keys.d/${config.lyte.username}" = {
      mode = "0444";
      text = lib.concatStringsSep "\n" config.lyte.userSshKeys + "\n";
    };

    # Local group memberships for the kanidm-provided user. The `members`
    # field accepts bare name strings and doesn't require the user to be
    # declared in `users.users` — it just writes the name into /etc/group.
    users.groups =
      let
        u = [ config.lyte.username ];
      in
      {
        wheel.members = u;
        video.members = u;
        dialout.members = u;
        uucp.members = u;
        power.members = u;
        kvm.members = u;
        input.members = u;
        users.members = u;
        networkmanager.members = u;
      };

    # Grant kanidm's "administrators" group wheel-equivalent sudo. Kanidm
    # group memberships flow through NSS, so `%administrators` resolves
    # to whatever kanidm currently reports.
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

    # Per-host one-shot migration: transition from the old local daniel
    # (uid/gid 1000) + nested `/home/daniel/.home` layout to kanidm-only
    # identity with flat `/home/daniel`. Runs once per host, marker-gated.
    systemd.services.migrate-daniel-to-kanidm = {
      description = "Chown /home/daniel to kanidm-provided uid + flatten .home + remove stale local passwd entries";
      wantedBy = [ "multi-user.target" ];
      after = [
        "systemd-tmpfiles-setup.service"
        "kanidm-unixd.service"
      ];
      before = [ "systemd-user-sessions.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script =
        let
          awk = "${pkgs.gawk}/bin/awk";
          chown' = "${pkgs.coreutils}/bin/chown";
          find = "${pkgs.findutils}/bin/find";
          xargs = "${pkgs.findutils}/bin/xargs";
          rsync = "${pkgs.rsync}/bin/rsync";
          rm = "${pkgs.coreutils}/bin/rm";
          rmdir = "${pkgs.coreutils}/bin/rmdir";
          install' = "${pkgs.coreutils}/bin/install";
          touch = "${pkgs.coreutils}/bin/touch";
          userdel = "${pkgs.shadow}/bin/userdel";
          groupdel = "${pkgs.shadow}/bin/groupdel";
          loginctl = "${pkgs.systemd}/bin/loginctl";
          u = config.lyte.username;
          home = config.lyte.userHome;
        in
        ''
          set -eu
          marker=/var/lib/lyte/migrate-daniel-to-kanidm.done
          if [ -e "$marker" ]; then exit 0; fi

          # Bail if the user has an active session — chown on live files
          # is risky and userdel won't kill it anyway.
          if ${loginctl} list-sessions --no-legend 2>/dev/null | ${awk} '{print $3}' | grep -qx ${u}; then
            echo "migrate-daniel-to-kanidm: active session for ${u}; skipping this boot"
            exit 0
          fi

          # Must have a kanidm-provided entry for the migration target.
          if ! getent passwd ${u} >/dev/null; then
            echo "migrate-daniel-to-kanidm: ${u} not resolvable via NSS; skipping"
            exit 0
          fi

          # 1. Flatten nested home: move /home/<u>/.home/* up one level.
          if [ -d ${home}/.home ]; then
            echo "migrate-daniel-to-kanidm: flattening ${home}/.home -> ${home}"
            ${rsync} -aHAX --remove-source-files ${home}/.home/ ${home}/
            # Purge now-empty subtree
            ${find} ${home}/.home -depth -type d -empty -exec ${rmdir} {} + || true
          fi

          # 1b. Retarget any surviving symlinks whose target was inside
          #     the now-empty .home/ tree. `.nix-profile`, Steam's
          #     proton prefix .dll shims, etc. rewrite ".home/" -> "".
          echo "migrate-daniel-to-kanidm: retargeting dangling ${home}/.home/* symlinks"
          ${find} ${home} -type l 2>/dev/null | while IFS= read -r link; do
            tgt=$(${pkgs.coreutils}/bin/readlink "$link" 2>/dev/null || true)
            case "$tgt" in
              ${home}/.home/*)
                newtgt="${home}/''${tgt#${home}/.home/}"
                if [ -e "$newtgt" ] || [ -L "$newtgt" ]; then
                  ${pkgs.coreutils}/bin/ln -sfn "$newtgt" "$link"
                fi
                ;;
            esac
          done

          # 2. chown everything under /home/<u> to the kanidm-provided
          #    uid/gid. Using the name via getent so we don't hardcode
          #    numeric values. Symlink targets aren't followed (-h at the
          #    chown level + --no-dereference), and read-only nix-store
          #    paths (e.g. from .direnv) are tolerated.
          ${find} ${home} -not -user ${u} -print0 2>/dev/null \
            | ${xargs} -0 -r ${chown'} -h --no-dereference ${u}:${u} 2>/dev/null || true
          ${find} ${home} -not -group ${u} -print0 2>/dev/null \
            | ${xargs} -0 -r ${chown'} -h --no-dereference :${u} 2>/dev/null || true

          # 3. Remove the old local daniel user/group from /etc/{passwd,group}.
          #    NixOS with mutableUsers=true leaves stale entries behind
          #    when a user is removed from the nix declaration.
          if ${awk} -F: -v u=${u} '$1 == u { exit 0 } END { exit 1 }' /etc/passwd; then
            # Only remove if this /etc/passwd entry is the pre-migration
            # local one (by uid 1000) — if kanidm has somehow written its
            # own entry to /etc/passwd, leave it alone.
            local_uid=$(${awk} -F: -v u=${u} '$1 == u { print $3 }' /etc/passwd)
            if [ "$local_uid" = 1000 ]; then
              echo "migrate-daniel-to-kanidm: removing stale local ${u} (uid 1000) from /etc/passwd"
              ${userdel} ${u} 2>/dev/null || true
              ${groupdel} ${u} 2>/dev/null || true
            fi
          fi

          ${install'} -d -m 0755 "$(dirname "$marker")"
          ${touch} "$marker"
        '';
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
