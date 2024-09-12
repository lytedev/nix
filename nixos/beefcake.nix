/*
if ur fans get loud:

# enable manual fan control
sudo nix run nixpkgs#ipmitool -- raw 0x30 0x30 0x01 0x00

# set fan speed to last byte as decimal
sudo nix run nixpkgs#ipmitool -- raw 0x30 0x30 0x02 0xff 0x00
*/
{
  # inputs,
  # outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  system.stateVersion = "24.05";
  home-manager.users.daniel.home.stateVersion = "24.05";
  networking.hostName = "beefcake";

  imports = [
    {
      # hardware and boot module
      networking.hostId = "541ede55";
      boot = {
        zfs = {
          extraPools = ["zstorage"];
        };
        supportedFilesystems = {
          zfs = true;
        };
        initrd.supportedFilesystems = {
          zfs = true;
        };
        kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
        initrd.availableKernelModules = ["ehci_pci" "mpt3sas" "usbhid" "sd_mod"];
        kernelModules = ["kvm-intel"];
        kernelParams = ["nohibernate"];
        loader.systemd-boot.enable = true;
        loader.efi.canTouchEfiVariables = true;
      };

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/992ce55c-7507-4d6b-938c-45b7e891f395";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/B6C4-7CF4";
        fsType = "vfat";
        options = ["fmask=0022" "dmask=0022"];
      };

      # should be mounted by auto-import; see boot.zfs.extraPools
      # fileSystems."/storage" = {
      #   device = "zstorage/storage";
      #   fsType = "zfs";
      # };

      fileSystems."/nix" = {
        device = "zstorage/nix";
        fsType = "zfs";
      };

      services.zfs.autoScrub.enable = true;
      services.zfs.autoSnapshot.enable = true;

      # TODO: nfs with zfs?
      # services.nfs.server.enable = true;
    }
    ({
      options,
      config,
      ...
    }: let
      inherit (lib) mkOption types;
    in {
      options.services.restic.commonPaths = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = [];
        description = ''
          Which paths to backup, in addition to ones specified via
          `dynamicFilesFrom`.  If null or an empty array and
          `dynamicFilesFrom` is also null, no backup command will be run.
           This can be used to create a prune-only job.
        '';
        example = [
          "/var/lib/postgresql"
          "/home/user/backup"
        ];
      };
    })
    {
      # sops secrets config
      sops = {
        defaultSopsFile = ../secrets/beefcake/secrets.yml;
        age = {
          sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
          keyFile = "/var/lib/sops-nix/key.txt";
          generateKey = true;
        };
      };
    }
    {
      sops.secrets = {
        netlify-ddns-password = {mode = "0400";};
      };
      services.deno-netlify-ddns-client = {
        passwordFile = config.sops.secrets.netlify-ddns-password.path;
      };
    }
    {
      # nix binary cache
      sops.secrets = {
        nix-cache-priv-key = {mode = "0400";};
      };
      services.nix-serve = {
        enable = true; # TODO: true
        secretKeyFile = config.sops.secrets.nix-cache-priv-key.path;
      };
      services.caddy.virtualHosts."nix.h.lyte.dev" = {
        extraConfig = ''
          reverse_proxy :${toString config.services.nix-serve.port}
        '';
      };
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      # regularly build this flake so we have stuff in the cache
      # TODO: schedule this for nightly builds instead of intervals based on boot time
      systemd.timers."build-lytedev-flake" = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "30m"; # 30 minutes after booting
          OnUnitActiveSec = "1d"; # every day afterwards
          Unit = "build-lytedev-flake.service";
        };
      };

      systemd.tmpfiles.settings = {
        "10-daniel-nightly-flake-build" = {
          "/home/daniel/.home/.cache/nightly-flake-builds" = {
            "d" = {
              mode = "0750";
              user = "daniel";
              group = "daniel";
            };
          };
        };
      };

      systemd.services."build-lytedev-flake" = {
        # TODO: might want to add root for the most recent results?
        script = ''
          # build self (main server) configuration
          nixos-rebuild build --flake git+https://git.lyte.dev/lytedev/nix.git --accept-flake-config
          # build desktop configuration
          nixos-rebuild build --flake git+https://git.lyte.dev/lytedev/nix.git#dragon --accept-flake-config
          # build main laptop configuration
          nixos-rebuild build --flake git+https://git.lyte.dev/lytedev/nix.git#foxtrot --accept-flake-config
        '';
        path = with pkgs; [openssh git nixos-rebuild];
        serviceConfig = {
          # TODO: mkdir -p...?
          WorkingDirectory = "/home/daniel/.home/.cache/nightly-flake-builds";
          Type = "oneshot";
          User = "daniel";
        };
      };

      networking = {
        extraHosts = ''
          ::1 nix.h.lyte.dev
          127.0.0.1 nix.h.lyte.dev
        '';
      };
    }
    {
      services.headscale = {
        enable = false; # TODO: setup headscale?
        address = "127.0.0.1";
        port = 7777;
        settings = {
          server_url = "https://tailscale.vpn.h.lyte.dev";
          db_type = "sqlite3";
          db_path = "/var/lib/headscale/db.sqlite";

          derp.server = {
            enable = true;
            region_id = 999;
            stun_listen_addr = "0.0.0.0:3478";
          };

          dns_config = {
            magic_dns = true;
            base_domain = "vpn.h.lyte.dev";
            domains = [
              "ts.vpn.h.lyte.dev"
            ];
            nameservers = [
              "1.1.1.1"
              # "192.168.0.1"
            ];
            override_local_dns = true;
          };
        };
      };
      services.caddy.virtualHosts."tailscale.vpn.h.lyte.dev" = lib.mkIf config.services.headscale.enable {
        extraConfig = ''
          reverse_proxy http://localhost:${toString config.services.headscale.port}
        '';
      };
      networking.firewall.allowedUDPPorts = lib.mkIf config.services.headscale.enable [3478];
    }
    {
      # TODO: I think I need to setup my account? wondering if this can be done in nix as well

      services.restic.commonPaths = ["/var/lib/soju" "/var/lib/private/soju"];
      services.soju = {
        enable = true;
        listen = ["irc+insecure://:6667"];
      };
      networking.firewall.allowedTCPPorts = [
        6667
      ];
    }
    # {
    #   # samba
    #   users.users.guest = {
    #     # used for anonymous samba access
    #     isSystemUser = true;
    #     group = "users";
    #     createHome = true;
    #   };
    #   users.users.scannerupload = {
    #     # used for scanner samba access
    #     isSystemUser = true;
    #     group = "users";
    #     createHome = true;
    #   };
    #   systemd.tmpfiles.rules = [
    #     "d /var/spool/samba 1777 root root -"
    #   ];
    #   services.samba-wsdd = {
    #     enable = true;
    #   };
    #   services.samba = {
    #     enable = true;
    #     openFirewall = true;
    #     securityType = "user";

    #     # not needed since I don't think I use printer sharing?
    #     # https://nixos.wiki/wiki/Samba#Printer_sharing
    #     # package = pkgs.sambaFull; # broken last I checked in nixpkgs?

    #     extraConfig = ''
    #       workgroup = WORKGROUP
    #       server string = beefcake
    #       netbios name = beefcake
    #       security = user
    #       #use sendfile = yes
    #       #max protocol = smb2
    #       # note: localhost is the ipv6 localhost ::1
    #       hosts allow = 100.64.0.0/10 192.168.0.0/16 127.0.0.1 localhost
    #       hosts deny = 0.0.0.0/0
    #       guest account = guest
    #       map to guest = never
    #       # load printers = yes
    #       # printing = cups
    #       # printcap name = cups
    #     '';
    #     shares = {
    #       libre = {
    #         path = "/storage/libre";
    #         browseable = "yes";
    #         "read only" = "no";
    #         "guest ok" = "yes";
    #         "create mask" = "0666";
    #         "directory mask" = "0777";
    #         # "force user" = "nobody";
    #         # "force group" = "users";
    #       };
    #       public = {
    #         path = "/storage/public";
    #         browseable = "yes";
    #         "read only" = "no";
    #         "guest ok" = "yes";
    #         "create mask" = "0664";
    #         "directory mask" = "0775";
    #         # "force user" = "nobody";
    #         # "force group" = "users";
    #       };
    #       family = {
    #         path = "/storage/family";
    #         browseable = "yes";
    #         "read only" = "no";
    #         "guest ok" = "no";
    #         "create mask" = "0660";
    #         "directory mask" = "0770";
    #         # "force user" = "nobody";
    #         # "force group" = "family";
    #       };
    #       scannerdocs = {
    #         path = "/storage/scannerdocs";
    #         browseable = "yes";
    #         "read only" = "no";
    #         "guest ok" = "no";
    #         "create mask" = "0600";
    #         "directory mask" = "0700";
    #         "valid users" = "scannerupload";
    #         "force user" = "scannerupload";
    #         "force group" = "users";
    #       };
    #       daniel = {
    #         path = "/storage/daniel";
    #         browseable = "yes";
    #         "read only" = "no";
    #         "guest ok" = "no";
    #         "create mask" = "0600";
    #         "directory mask" = "0700";
    #         # "force user" = "daniel";
    #         # "force group" = "users";
    #       };
    #       # printers = {
    #       #   comment = "All Printers";
    #       #   path = "/var/spool/samba";
    #       #   public = "yes";
    #       #   browseable = "yes";
    #       #   # to allow user 'guest account' to print.
    #       #   "guest ok" = "yes";
    #       #   writable = "no";
    #       #   printable = "yes";
    #       #   "create mode" = 0700;
    #       # };
    #     };
    #   };
    # }
    {
      # nextcloud
      # TODO: investigate https://carlosvaz.com/posts/the-holy-grail-nextcloud-setup-made-easy-by-nixos/
      # services.postgresql = {
      #   ensureDatabases = [
      #     "nextcloud"
      #   ];
      #   ensureUsers = [
      #     {
      #       name = "nextcloud";
      #       ensureDBOwnership = true;
      #     }
      #   ];
      # };
      # nextcloud
      # users.users.nextcloud = {
      #   isSystemUser = true;
      #   createHome = false;
      #   group = "nextcloud";
      # };
    }
    {
      # plausible
      services.postgresql = {
        ensureDatabases = ["plausible"];
        ensureUsers = [
          {
            name = "plausible";
            ensureDBOwnership = true;
          }
        ];
      };
      users.users.plausible = {
        isSystemUser = true;
        createHome = false;
        group = "plausible";
      };
      users.extraGroups = {
        "plausible" = {};
      };
      services.plausible = {
        enable = true;
        database = {
          clickhouse.setup = true;
          postgres = {
            setup = false;
            dbname = "plausible";
          };
        };
        server = {
          baseUrl = "https://a.lyte.dev";
          disableRegistration = true;
          port = 8899;
          secretKeybaseFile = config.sops.secrets.plausible-secret-key-base.path;
        };
        adminUser = {
          activate = false;
          email = "daniel@lyte.dev";
          passwordFile = config.sops.secrets.plausible-admin-password.path;
        };
      };
      sops.secrets = {
        plausible-secret-key-base = {
          owner = "plausible";
          group = "plausible";
        };
        plausible-admin-password = {
          owner = "plausible";
          group = "plausible";
        };
      };
      systemd.services.plausible = {
        serviceConfig.User = "plausible";
        serviceConfig.Group = "plausible";
      };
      services.caddy.virtualHosts."a.lyte.dev" = {
        extraConfig = ''
          reverse_proxy :${toString config.services.plausible.server.port}
        '';
      };
    }
    {
      # clickhouse
      environment.etc = {
        "clickhouse-server/users.d/disable-logging-query.xml" = {
          text = ''
            <clickhouse>
              <profiles>
                <default>
                  <log_queries>0</log_queries>
                  <log_query_threads>0</log_query_threads>
                </default>
              </profiles>
            </clickhouse>
          '';
        };
        "clickhouse-server/config.d/reduce-logging.xml" = {
          text = ''
            <clickhouse>
              <logger>
                <level>warning</level>
                <console>true</console>
              </logger>
              <query_thread_log remove="remove"/>
              <query_log remove="remove"/>
              <text_log remove="remove"/>
              <trace_log remove="remove"/>
              <metric_log remove="remove"/>
              <asynchronous_metric_log remove="remove"/>
              <session_log remove="remove"/>
              <part_log remove="remove"/>
            </clickhouse>
          '';
        };
      };
      services.restic.commonPaths = [
        # "/var/lib/clickhouse"
      ];
    }
    {
      # family storage
      users.extraGroups = {
        "family" = {};
      };
      systemd.tmpfiles.settings = {
        "10-family" = {
          "/storage/family" = {
            "d" = {
              mode = "0770";
              user = "root";
              group = "family";
            };
          };
          "/storage/family/valerie" = {
            "d" = {
              mode = "0750";
              user = "valerie";
              group = "family";
            };
          };
          "/storage/family/daniel" = {
            "d" = {
              mode = "0750";
              user = "daniel";
              group = "family";
            };
          };
        };
      };
      services.restic.commonPaths = [
        "/storage/family"
      ];
    }
    {
      # daniel augments
      systemd.tmpfiles.settings = {
        "10-daniel" = {
          "/storage/daniel" = {
            "d" = {
              mode = "0700";
              user = "daniel";
              group = "nogroup";
            };
          };
          "/storage/daniel/critical" = {
            "d" = {
              mode = "0700";
              user = "daniel";
              group = "nogroup";
            };
          };
        };
      };
      users.groups.daniel.members = ["daniel"];
      users.groups.nixadmin.members = ["daniel"];
      users.users.daniel = {
        extraGroups = [
          # "nixadmin" # write access to /etc/nixos/ files
          "wheel" # sudo access
          "caddy" # write access to public static files
          "users" # general users group
          "jellyfin" # write access to jellyfin files
          "audiobookshelf" # write access to audiobookshelf files
          "flanilla" # minecraft server manager
          "forgejo"
        ];
      };
      services.restic.commonPaths = [
        "/storage/daniel"
      ];

      services.postgresql = {
        ensureDatabases = ["daniel"];
        ensureUsers = [
          {
            name = "daniel";
            ensureDBOwnership = true;
          }
        ];
      };
    }
    {
      systemd.tmpfiles.settings = {
        "10-jellyfin" = {
          "/storage/jellyfin" = {
            "d" = {
              mode = "0770";
              user = "jellyfin";
              group = "wheel";
            };
          };
          "/storage/jellyfin/movies" = {
            "d" = {
              mode = "0770";
              user = "jellyfin";
              group = "wheel";
            };
          };
          "/storage/jellyfin/tv" = {
            "d" = {
              mode = "0770";
              user = "jellyfin";
              group = "wheel";
            };
          };
          "/storage/jellyfin/music" = {
            "d" = {
              mode = "0770";
              user = "jellyfin";
              group = "wheel";
            };
          };
        };
      };
      services.jellyfin = {
        enable = true;
        openFirewall = false;
        # uses port 8096 by default, configurable from admin UI
      };
      services.caddy.virtualHosts."video.lyte.dev" = {
        extraConfig = ''reverse_proxy :8096'';
      };
      # NOTE: this server's xeon chips DO NOT seem to support quicksync or graphics in general
      # but I can probably throw in a crappy GPU (or a big, cheap ebay GPU for ML
      # stuff, too?) and get good transcoding performance

      # jellyfin hardware encoding
      # hardware.graphics = {
      #   enable = true;
      #   extraPackages = with pkgs; [
      #     intel-media-driver
      #     vaapiIntel
      #     vaapiVdpau
      #     libvdpau-va-gl
      #     intel-compute-runtime
      #   ];
      # };
      # nixpkgs.config.packageOverrides = pkgs: {
      #   vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
      # };
    }
    {
      systemd.tmpfiles.settings = {
        "10-postgres" = {
          "/storage/postgres" = {
            "d" = {
              mode = "0750";
              user = "postgres";
              group = "postgres";
            };
          };
        };
      };
      services.postgresql = {
        enable = true;
        dataDir = "/storage/postgres";
        enableTCPIP = true;

        package = pkgs.postgresql_15;

        # https://www.postgresql.org/docs/current/auth-pg-hba-conf.html
        # TODO: give the "daniel" user access to all databases
        authentication = pkgs.lib.mkOverride 10 ''
          #type database  user      auth-method    auth-options
          local all       postgres  peer           map=superuser_map
          local all       daniel    peer           map=superuser_map
          local sameuser  all       peer           map=superuser_map

          # lan ipv4
          host  all       daniel    192.168.0.0/16 trust
          host  all       daniel    10.0.0.0/24    trust

          # tailnet ipv4
          host  all       daniel    100.64.0.0/10 trust
        '';

        identMap = ''
          # map            system_user db_user
          superuser_map    root        postgres
          superuser_map    postgres    postgres
          superuser_map    daniel      postgres

          # Let other names login as themselves
          superuser_map    /^(.*)$     \1
        '';
      };

      services.postgresqlBackup = {
        enable = true;
        backupAll = true;
        compression = "none"; # hoping for restic deduplication here?
        location = "/storage/postgres-backups";
        startAt = "*-*-* 03:00:00";
      };
      services.restic.commonPaths = [
        "/storage/postgres-backups"
      ];
    }
    {
      # friends
      users.users.ben = {
        isNormalUser = true;
        packages = [pkgs.vim];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKUfLZ+IX85p9355Po2zP1H2tAxiE0rE6IYb8Sf+eF9T ben@benhany.com"
        ];
      };

      users.users.alan = {
        isNormalUser = true;
        packages = [pkgs.vim];
        # openssh.authorizedKeys.keys = [];
      };
    }
    {
      # restic backups
      sops.secrets = {
        restic-ssh-priv-key-benland = {mode = "0400";};
        restic-rascal-passphrase = {
          mode = "0400";
        };
        restic-rascal-ssh-private-key = {
          mode = "0400";
        };
      };
      users.groups.restic = {};
      users.users.restic = {
        # used for other machines to backup to
        isSystemUser = true;
        group = "restic";
        openssh.authorizedKeys.keys = [] ++ config.users.users.daniel.openssh.authorizedKeys.keys;
      };
      systemd.tmpfiles.settings = {
        "10-backups-local" = {
          "/storage/backups/local" = {
            "d" = {
              mode = "0750";
              user = "root";
              group = "wheel";
            };
          };
        };
      };
      services.restic.backups = let
        defaults = {
          passwordFile = config.sops.secrets.restic-rascal-passphrase.path;
          paths =
            config.services.restic.commonPaths
            ++ [
            ];
          initialize = true;
          exclude = [];
          timerConfig = {
            OnCalendar = ["04:45" "17:45"];
          };
        };
      in {
        local =
          defaults
          // {
            repository = "/storage/backups/local";
          };
        rascal =
          defaults
          // {
            extraOptions = [
              "sftp.command='ssh beefcake@rascal -i /root/.ssh/id_ed25519 -s sftp'"
            ];
            repository = "sftp://beefcake@rascal://storage/backups/beefcake";
          };
        # TODO: add ruby?
        benland =
          defaults
          // {
            passwordFile = config.sops.secrets.restic-ssh-priv-key-benland.path;
            extraOptions = [
              "sftp.command='ssh daniel@n.benhaney.com -p 10022 -i /root/.ssh/id_ed25519 -s sftp'"
            ];
            repository = "sftp://daniel@n.benhaney.com://storage/backups/beefcake";
          };
      };
    }
    {
      systemd.tmpfiles.settings = {
        "10-caddy" = {
          "/storage/files.lyte.dev" = {
            "d" = {
              mode = "2775";
              user = "root";
              group = "wheel";
            };
          };
        };
      };
      services.restic.commonPaths = [
        "/storage/files.lyte.dev"
      ];
      services.caddy = {
        # TODO: 502 and other error pages
        enable = true;
        email = "daniel@lyte.dev";
        adapter = "caddyfile";
        virtualHosts = {
          "files.lyte.dev" = {
            # TODO: customize the files.lyte.dev template?
            extraConfig = ''
              header {
                Access-Control-Allow-Origin "{http.request.header.Origin}"
                Access-Control-Allow-Credentials true
                Access-Control-Allow-Methods *
                Access-Control-Allow-Headers *
                Vary Origin
                defer
              }
              file_server browse {
                # browse template
                # hide .*
                root /storage/files.lyte.dev
              }
            '';
          };
        };
        # acmeCA = "https://acme-staging-v02.api.letsencrypt.org/directory";
      };
    }
    {
      systemd.tmpfiles.settings = {
        "10-forgejo" = {
          "/storage/forgejo" = {
            "d" = {
              mode = "0700";
              user = "forgejo";
              group = "nogroup";
            };
          };
        };
      };
      services.forgejo = {
        enable = true;
        stateDir = "/storage/forgejo";
        settings = {
          DEFAULT = {
            APP_NAME = "git.lyte.dev";
          };
          server = {
            ROOT_URL = "https://git.lyte.dev";
            HTTP_ADDR = "127.0.0.1";
            HTTP_PORT = 3088;
            DOMAIN = "git.lyte.dev";
          };
          actions = {
            ENABLED = true;
          };
          service = {
            DISABLE_REGISTRATION = true;
          };
          session = {
            COOKIE_SECURE = true;
          };
          log = {
            # LEVEL = "Debug";
          };
          ui = {
            THEMES = "forgejo-auto,forgejo-light,forgejo-dark";
            DEFAULT_THEME = "forgejo-auto";
          };
          indexer = {
            REPO_INDEXER_ENABLED = "true";
            REPO_INDEXER_PATH = "indexers/repos.bleve";
            MAX_FILE_SIZE = "1048576";
            # REPO_INDEXER_INCLUDE =
            REPO_INDEXER_EXCLUDE = "resources/bin/**";
          };
        };
        lfs = {
          enable = true;
        };
        dump = {
          enable = false;
        };
        database = {
          # TODO: move to postgres?
          type = "sqlite3";
        };
      };
      services.restic.commonPaths = [
        config.services.forgejo.stateDir
      ];
      sops.secrets = {
        "forgejo-runner.env" = {mode = "0400";};
      };
      systemd.services.gitea-runner-beefcake.after = ["sops-nix.service"];
      services.gitea-actions-runner = {
        # TODO: simple git-based automation would be dope? maybe especially for
        # mirroring to github super easy?
        package = pkgs.forgejo-runner;
        instances."beefcake" = {
          enable = true;
          name = "beefcake";
          url = "https://git.lyte.dev";
          settings = {
            container = {
              # use the shared network which is bridged by default
              # this lets us hit git.lyte.dev just fine
              network = "podman";
            };
          };
          labels = [
            # type ":host" does not depend on docker/podman/lxc
            "podman"
            "nix:docker://git.lyte.dev/lytedev/nix:latest"
            "beefcake:host"
            "nixos-host:host"
          ];
          tokenFile = config.sops.secrets."forgejo-runner.env".path;
          hostPackages = with pkgs; [
            nix
            bash
            coreutils
            curl
            gawk
            gitMinimal
            gnused
            nodejs
            gnutar # needed for cache action
            wget
          ];
        };
      };
      # environment.systemPackages = with pkgs; [nodejs];
      services.caddy.virtualHosts."git.lyte.dev" = {
        extraConfig = ''
          reverse_proxy :${toString config.services.forgejo.settings.server.HTTP_PORT}
        '';
      };
      services.caddy.virtualHosts."http://git.beefcake.lan" = {
        extraConfig = ''
          reverse_proxy :${toString config.services.forgejo.settings.server.HTTP_PORT}
        '';
      };
    }
    {
      services.restic.commonPaths = [
        config.services.vaultwarden.backupDir
      ];
      services.vaultwarden = {
        enable = true;
        backupDir = "/storage/vaultwarden/backups";
        config = {
          DOMAIN = "https://bw.lyte.dev";
          SIGNUPS_ALLOWED = "false";
          ROCKET_ADDRESS = "127.0.0.1";
          ROCKET_PORT = 8222;
          # TODO: smtp setup?
          # right now, I think I configured this manually by temporarily setting ADMIN_TOKEN
          # and then configuring in https://bw.lyte.dev/admin
        };
      };
      services.caddy.virtualHosts."bw.lyte.dev" = {
        extraConfig = ''reverse_proxy :${toString config.services.vaultwarden.config.ROCKET_PORT}'';
      };
    }
    {
      users.users.atuin = {
        isSystemUser = true;
        createHome = false;
        group = "atuin";
      };
      users.extraGroups = {
        "atuin" = {};
      };
      services.postgresql = {
        ensureDatabases = ["atuin"];
        ensureUsers = [
          {
            name = "atuin";
            ensureDBOwnership = true;
          }
        ];
      };
      services.atuin = {
        enable = true;
        database = {
          createLocally = false;
          # NOTE: this uses postgres over the unix domain socket by default
          # uri = "postgresql://atuin@localhost:5432/atuin";
        };
        openRegistration = false;
        # TODO: would be neat to have a way to "force" a registration on the server
      };
      systemd.services.atuin.serviceConfig = {
        Group = "atuin";
        User = "atuin";
      };
      services.caddy.virtualHosts."atuin.h.lyte.dev" = {
        extraConfig = ''reverse_proxy :${toString config.services.atuin.port}'';
      };
    }
    # {
    #   # jland minecraft server
    #   users.groups.jland = {
    #     gid = 982;
    #   };
    #   users.users.jland = {
    #     uid = 986;
    #     isSystemUser = true;
    #     createHome = false;
    #     group = "jland";
    #   };
    #   virtualisation.oci-containers.containers.minecraft-jland = {
    #     autoStart = false;

    #     # sending commands: https://docker-minecraft-server.readthedocs.io/en/latest/commands/
    #     image = "docker.io/itzg/minecraft-server";
    #     # user = "${toString config.users.users.jland.uid}:${toString config.users.groups.jland.gid}";
    #     extraOptions = [
    #       "--tty"
    #       "--interactive"
    #     ];
    #     environment = {
    #       EULA = "true";
    #       # UID = toString config.users.users.jland.uid;
    #       # GID = toString config.users.groups.jland.gid;
    #       STOP_SERVER_ANNOUNCE_DELAY = "20";
    #       TZ = "America/Chicago";
    #       VERSION = "1.20.1";
    #       MEMORY = "8G";
    #       MAX_MEMORY = "16G";
    #       TYPE = "FORGE";
    #       FORGE_VERSION = "47.1.3";
    #       ALLOW_FLIGHT = "true";
    #       ENABLE_QUERY = "true";

    #       MODPACK = "/data/origination-files/Server-Files-0.2.14.zip";

    #       # TYPE = "AUTO_CURSEFORGE";
    #       # CF_SLUG = "monumental-experience";
    #       # CF_FILE_ID = "4826863"; # 2.2.53

    #       # due to
    #       # Nov 02 13:45:22 beefcake minecraft-jland[2738672]: me.itzg.helpers.errors.GenericException: The modpack authors have indicated this file is not allowed for project distribution. Please download the client zip file from https://www.curseforge.com/minecraft/modpacks/monumental-experience and pass via CF_MODPACK_ZIP environment variable or place indownloads repo directory.
    #       # we must upload manually
    #       # CF_MODPACK_ZIP = "/data/origination-files/Monumental+Experience-2.2.53.zip";

    #       # ENABLE_AUTOPAUSE = "true"; # TODO: must increate or disable max-tick-time
    #       # May also have mod/loader incompatibilities?
    #       # https://docker-minecraft-server.readthedocs.io/en/latest/misc/autopause-autostop/autopause/
    #     };
    #     environmentFiles = [
    #       # config.sops.secrets."jland.env".path
    #     ];
    #     ports = ["26965:25565"];
    #     volumes = [
    #       "/storage/jland/data:/data"
    #       "/storage/jland/worlds:/worlds"
    #     ];
    #   };
    #   networking.firewall.allowedTCPPorts = [
    #     26965
    #   ];
    # }
    # {
    #   # dawncraft minecraft server
    #   systemd.tmpfiles.rules = [
    #     "d /storage/dawncraft/ 0770 1000 1000 -"
    #     "d /storage/dawncraft/data/ 0770 1000 1000 -"
    #     "d /storage/dawncraft/worlds/ 0770 1000 1000 -"
    #     "d /storage/dawncraft/downloads/ 0770 1000 1000 -"
    #   ];
    #   virtualisation.oci-containers.containers.minecraft-dawncraft = {
    #     autoStart = false;

    #     # sending commands: https://docker-minecraft-server.readthedocs.io/en/latest/commands/
    #     image = "docker.io/itzg/minecraft-server";
    #     extraOptions = [
    #       "--tty"
    #       "--interactive"
    #     ];
    #     environment = {
    #       EULA = "true";

    #       STOP_SERVER_ANNOUNCE_DELAY = "20";
    #       TZ = "America/Chicago";
    #       VERSION = "1.18.2";
    #       MEMORY = "8G";
    #       MAX_MEMORY = "32G";

    #       ALLOW_FLIGHT = "true";
    #       ENABLE_QUERY = "true";
    #       SERVER_PORT = "26968";
    #       QUERY_PORT = "26968";

    #       TYPE = "AUTO_CURSEFORGE";
    #       CF_SLUG = "dawn-craft";

    #       CF_EXCLUDE_MODS = "368398";
    #       CF_FORCE_SYNCHRONIZE = "true";
    #       # CF_FILE_ID = "5247696"; # 2.0.7 server
    #     };
    #     environmentFiles = [
    #       config.sops.secrets."dawncraft.env".path
    #     ];
    #     ports = ["26968:26968/tcp" "26968:26968/udp"];
    #     volumes = [
    #       "/storage/dawncraft/data:/data"
    #       "/storage/dawncraft/worlds:/worlds"
    #       "/storage/dawncraft/downloads:/downloads"
    #     ];
    #   };
    #   networking.firewall.allowedTCPPorts = [
    #     26968
    #   ];
    # }
    # {
    #   # flanilla family minecraft server
    #   users.groups.flanilla = {};
    #   users.users.flanilla = {
    #     isSystemUser = true;
    #     createHome = false;
    #     group = "flanilla";
    #   };
    #   virtualisation.oci-containers.containers.minecraft-flanilla = {
    #     autoStart = true;

    #     image = "docker.io/itzg/minecraft-server";
    #     user = "${toString config.users.users.flanilla.uid}:${toString config.users.groups.flanilla.gid}";
    #     extraOptions = ["--tty" "--interactive"];
    #     environment = {
    #       EULA = "true";
    #       UID = toString config.users.users.flanilla.uid;
    #       GID = toString config.users.groups.flanilla.gid;
    #       STOP_SERVER_ANNOUNCE_DELAY = "20";
    #       TZ = "America/Chicago";
    #       VERSION = "1.20.4";
    #       OPS = "lytedev";
    #       MODE = "creative";
    #       DIFFICULTY = "peaceful";
    #       ONLINE_MODE = "false";
    #       MEMORY = "8G";
    #       MAX_MEMORY = "16G";
    #       ALLOW_FLIGHT = "true";
    #       ENABLE_QUERY = "true";
    #       ENABLE_COMMAND_BLOCK = "true";
    #     };

    #     environmentFiles = [
    #       # config.sops.secrets."flanilla.env".path
    #     ];

    #     ports = ["26966:25565"];

    #     volumes = [
    #       "/storage/flanilla/data:/data"
    #       "/storage/flanilla/worlds:/worlds"
    #     ];
    #   };
    #   networking.firewall.allowedTCPPorts = [
    #     26966
    #   ];
    # }
    # ({options, ...}: let
    #   toml = pkgs.formats.toml {};
    #   package = pkgs.kanidm;
    #   domain = "idm.h.lyte.dev";
    #   name = "kanidm";
    #   storage = "/storage/${name}";
    #   cert = "${storage}/certs/idm.h.lyte.dev.crt";
    #   key = "${storage}/certs/idm.h.lyte.dev.key";

    #   serverSettings = {
    #     inherit domain;
    #     bindaddress = "127.0.0.1:8443";
    #     # ldapbindaddress
    #     tls_chain = cert;
    #     tls_key = key;
    #     origin = "https://${domain}";
    #     db_path = "${storage}/data/kanidm.db";
    #     log_level = "info";
    #     online_backup = {
    #       path = "${storage}/backups/";
    #       schedule = "00 22 * * *";
    #       # versions = 7;
    #     };
    #   };

    #   unixdSettings = {
    #     hsm_pin_path = "/var/cache/${name}-unixd/hsm-pin";
    #     pam_allowed_login_groups = [];
    #   };

    #   clientSettings = {
    #     uri = "https://idm.h.lyte.dev";
    #   };

    #   user = name;
    #   group = name;
    #   serverConfigFile = toml.generate "server.toml" serverSettings;
    #   unixdConfigFile = toml.generate "kanidm-unixd.toml" unixdSettings;
    #   clientConfigFile = toml.generate "kanidm-config.toml" clientSettings;

    #   defaultServiceConfig = {
    #     BindReadOnlyPaths = [
    #       "/nix/store"
    #       "-/etc/resolv.conf"
    #       "-/etc/nsswitch.conf"
    #       "-/etc/hosts"
    #       "-/etc/localtime"
    #     ];
    #     CapabilityBoundingSet = [];
    #     # ProtectClock= adds DeviceAllow=char-rtc r
    #     DeviceAllow = "";
    #     # Implies ProtectSystem=strict, which re-mounts all paths
    #     # DynamicUser = true;
    #     LockPersonality = true;
    #     MemoryDenyWriteExecute = true;
    #     NoNewPrivileges = true;
    #     PrivateDevices = true;
    #     PrivateMounts = true;
    #     PrivateNetwork = true;
    #     PrivateTmp = true;
    #     PrivateUsers = true;
    #     ProcSubset = "pid";
    #     ProtectClock = true;
    #     ProtectHome = true;
    #     ProtectHostname = true;
    #     # Would re-mount paths ignored by temporary root
    #     #ProtectSystem = "strict";
    #     ProtectControlGroups = true;
    #     ProtectKernelLogs = true;
    #     ProtectKernelModules = true;
    #     ProtectKernelTunables = true;
    #     ProtectProc = "invisible";
    #     RestrictAddressFamilies = [];
    #     RestrictNamespaces = true;
    #     RestrictRealtime = true;
    #     RestrictSUIDSGID = true;
    #     SystemCallArchitectures = "native";
    #     SystemCallFilter = ["@system-service" "~@privileged @resources @setuid @keyring"];
    #     # Does not work well with the temporary root
    #     #UMask = "0066";
    #   };
    # in {
    #   # kanidm

    #   config = {
    #     # we need a mechanism to get the certificates that caddy provisions for us
    #     systemd.timers."copy-kanidm-certificates-from-caddy" = {
    #       wantedBy = ["timers.target"];
    #       timerConfig = {
    #         OnBootSec = "10m"; # 10 minutes after booting
    #         OnUnitActiveSec = "5m"; # every 5 minutes afterwards
    #         Unit = "copy-kanidm-certificates-from-caddy.service";
    #       };
    #     };

    #     systemd.services."copy-kanidm-certificates-from-caddy" = {
    #       script = ''
    #         umask 077
    #         install -d -m 0700 -o "${user}" -g "${group}" "${storage}/data" "${storage}/certs"
    #         cd /var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/idm.h.lyte.dev
    #         install -m 0700 -o "${user}" -g "${group}" idm.h.lyte.dev.key idm.h.lyte.dev.crt "${storage}/certs"
    #       '';
    #       path = with pkgs; [rsync];
    #       serviceConfig = {
    #         Type = "oneshot";
    #         User = "root";
    #       };
    #     };

    #     environment.systemPackages = [package];

    #     # TODO: should I use this for /storage/kanidm/certs etc.?
    #     systemd.tmpfiles.settings."10-kanidm" = {
    #       "${serverSettings.online_backup.path}".d = {
    #         inherit user group;
    #         mode = "0700";
    #       };
    #       # "${builtins.dirOf unixdSettings.hsm_pin_path}".d = {
    #       #   user = "${user}-unixd";
    #       #   group = "${group}-unixd";
    #       #   mode = "0700";
    #       # };
    #       "${storage}/data".d = {
    #         inherit user group;
    #         mode = "0700";
    #       };
    #       "${storage}/certs".d = {
    #         inherit user group;
    #         mode = "0700";
    #       };
    #     };

    #     users.groups = {
    #       ${group} = {};
    #       "${group}-unixd" = {};
    #     };

    #     users.users.${user} = {
    #       inherit group;
    #       description = "kanidm server";
    #       isSystemUser = true;
    #       packages = [package];
    #     };
    #     users.users."${user}-unixd" = {
    #       group = "${group}-unixd";
    #       description = lib.mkForce "kanidm PAM daemon";
    #       isSystemUser = true;
    #     };

    #     # the kanidm module in nixpkgs was not working for me, so I rolled my own
    #     # loosely based off it
    #     systemd.services.kanidm = {
    #       enable = true;
    #       path = with pkgs; [openssl] ++ [package];
    #       description = "kanidm identity management daemon";
    #       wantedBy = ["multi-user.target"];
    #       after = ["network.target"];
    #       requires = ["copy-kanidm-certificates-from-caddy.service"];
    #       script = ''
    #         pwd
    #         ls -la
    #         ls -laR /storage/kanidm
    #         ${package}/bin/kanidmd server -c ${serverConfigFile}
    #       '';
    #       # environment.RUST_LOG = serverSettings.log_level;
    #       serviceConfig = lib.mkMerge [
    #         defaultServiceConfig
    #         {
    #           StateDirectory = name;
    #           StateDirectoryMode = "0700";
    #           RuntimeDirectory = "${name}d";
    #           User = user;
    #           Group = group;

    #           AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];
    #           CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];
    #           PrivateUsers = lib.mkForce false;
    #           PrivateNetwork = lib.mkForce false;
    #           RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
    #           # TemporaryFileSystem = "/:ro";
    #           BindReadOnlyPaths = [
    #             "${storage}/certs"
    #           ];
    #           BindPaths = [
    #             "${storage}/data"

    #             # socket
    #             "/run/${name}d:/run/${name}d"

    #             # backups
    #             serverSettings.online_backup.path
    #           ];
    #         }
    #       ];
    #     };

    #     systemd.services.kanidm-unixd = {
    #       description = "Kanidm PAM daemon";
    #       wantedBy = ["multi-user.target"];
    #       after = ["network.target"];
    #       restartTriggers = [unixdConfigFile clientConfigFile];
    #       serviceConfig = lib.mkMerge [
    #         defaultServiceConfig
    #         {
    #           CacheDirectory = "${name}-unixd";
    #           CacheDirectoryMode = "0700";
    #           RuntimeDirectory = "${name}-unixd";
    #           ExecStart = "${package}/bin/kanidm_unixd";
    #           User = "${user}-unixd";
    #           Group = "${group}-unixd";

    #           BindReadOnlyPaths = [
    #             "-/etc/kanidm"
    #             "-/etc/static/kanidm"
    #             "-/etc/ssl"
    #             "-/etc/static/ssl"
    #             "-/etc/passwd"
    #             "-/etc/group"
    #           ];

    #           BindPaths = [
    #             # socket
    #             "/run/kanidm-unixd:/var/run/kanidm-unixd"
    #           ];

    #           # Needs to connect to kanidmd
    #           PrivateNetwork = lib.mkForce false;
    #           RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
    #           TemporaryFileSystem = "/:ro";
    #         }
    #       ];
    #       environment.RUST_LOG = serverSettings.log_level;
    #     };

    #     systemd.services.kanidm-unixd-tasks = {
    #       description = "Kanidm PAM home management daemon";
    #       wantedBy = ["multi-user.target"];
    #       after = ["network.target" "kanidm-unixd.service"];
    #       partOf = ["kanidm-unixd.service"];
    #       restartTriggers = [unixdConfigFile clientConfigFile];
    #       serviceConfig = {
    #         ExecStart = "${package}/bin/kanidm_unixd_tasks";

    #         BindReadOnlyPaths = [
    #           "/nix/store"
    #           "-/etc/resolv.conf"
    #           "-/etc/nsswitch.conf"
    #           "-/etc/hosts"
    #           "-/etc/localtime"
    #           "-/etc/kanidm"
    #           "-/etc/static/kanidm"
    #         ];
    #         BindPaths = [
    #           # To manage home directories
    #           "/home"

    #           # To connect to kanidm-unixd
    #           "/run/kanidm-unixd:/var/run/kanidm-unixd"
    #         ];
    #         # CAP_DAC_OVERRIDE is needed to ignore ownership of unixd socket
    #         CapabilityBoundingSet = ["CAP_CHOWN" "CAP_FOWNER" "CAP_DAC_OVERRIDE" "CAP_DAC_READ_SEARCH"];
    #         IPAddressDeny = "any";
    #         # Need access to users
    #         PrivateUsers = false;
    #         # Need access to home directories
    #         ProtectHome = false;
    #         RestrictAddressFamilies = ["AF_UNIX"];
    #         TemporaryFileSystem = "/:ro";
    #         Restart = "on-failure";
    #       };
    #       environment.RUST_LOG = serverSettings.log_level;
    #     };

    #     environment.etc = {
    #       "kanidm/server.toml".source = serverConfigFile;
    #       "kanidm/config".source = clientConfigFile;
    #       "kanidm/unixd".source = unixdConfigFile;
    #     };

    #     system.nssModules = [package];

    #     system.nssDatabases.group = [name];
    #     system.nssDatabases.passwd = [name];

    #     # environment.etc."kanidm/server.toml" = {
    #     #   mode = "0600";
    #     #   group = "kanidm";
    #     #   user = "kanidm";
    #     # };

    #     # environment.etc."kanidm/config" = {
    #     #   mode = "0600";
    #     #   group = "kanidm";
    #     #   user = "kanidm";
    #     # };

    #     services.caddy.virtualHosts."idm.h.lyte.dev" = {
    #       extraConfig = ''reverse_proxy https://idm.h.lyte.dev:8443'';
    #     };

    #     networking = {
    #       extraHosts = ''
    #         ::1 idm.h.lyte.dev
    #         127.0.0.1 idm.h.lyte.dev
    #       '';
    #     };
    #   };
    # })
    {
      systemd.tmpfiles.settings = {
        "10-audiobookshelf" = {
          "/storage/audiobookshelf" = {
            "d" = {
              mode = "0770";
              user = "audiobookshelf";
              group = "wheel";
            };
          };
          "/storage/audiobookshelf/audiobooks" = {
            "d" = {
              mode = "0770";
              user = "audiobookshelf";
              group = "wheel";
            };
          };
          "/storage/audiobookshelf/podcasts" = {
            "d" = {
              mode = "0770";
              user = "audiobookshelf";
              group = "wheel";
            };
          };
        };
      };
      users.groups.audiobookshelf = {};
      users.users.audiobookshelf = {
        isSystemUser = true;
        group = "audiobookshelf";
      };
      services.audiobookshelf = {
        enable = true;
        dataDir = "/storage/audiobookshelf";
        port = 8523;
      };
      systemd.services.audiobookshelf.serviceConfig = {
        WorkingDirectory = lib.mkForce config.services.audiobookshelf.dataDir;
        StateDirectory = lib.mkForce config.services.audiobookshelf.dataDir;
        Group = "audiobookshelf";
        User = "audiobookshelf";
      };
      services.caddy.virtualHosts."audio.lyte.dev" = {
        extraConfig = ''reverse_proxy :${toString config.services.audiobookshelf.port}'';
      };
    }
    {
      # prometheus
      services.restic.commonPaths = [
        # TODO: do I want this backed up?
        # "/var/lib/prometheus"
      ];
      services.prometheus = {
        enable = true;
        checkConfig = true;
        listenAddress = "127.0.0.1";
        port = 9090;
        scrapeConfigs = [
          {
            job_name = "beefcake";
            static_configs = [
              {
                targets = let inherit (config.services.prometheus.exporters.node) port listenAddress; in ["${listenAddress}:${toString port}"];
              }
              {
                targets = let inherit (config.services.prometheus.exporters.zfs) port listenAddress; in ["${listenAddress}:${toString port}"];
              }
              {
                targets = let inherit (config.services.prometheus.exporters.postgres) port listenAddress; in ["${listenAddress}:${toString port}"];
              }
            ];
          }
        ];
        exporters = {
          postgres = {
            enable = true;
            listenAddress = "127.0.0.1";
            runAsLocalSuperUser = true;
          };
          node = {
            enable = true;
            listenAddress = "127.0.0.1";
            enabledCollectors = [
              "systemd"
            ];
          };
          zfs = {
            enable = true;
            listenAddress = "127.0.0.1";
          };
        };
      };
      # TODO: promtail?
      # idrac exporter?
      # restic exporter?
      # smartctl exporter?
      # systemd exporter?
      # NOTE: we probably don't want this exposed
      # services.caddy.virtualHosts."prometheus.h.lyte.dev" = {
      #   extraConfig = ''reverse_proxy :${toString config.services.prometheus.port}'';
      # };
    }
    {
      # grafana
      systemd.tmpfiles.settings = {
        "10-grafana" = {
          "/storage/grafana" = {
            "d" = {
              mode = "0750";
              user = "root";
              group = "family";
            };
          };
        };
      };
      services.restic.commonPaths = [
        "/storage/grafana"
      ];
      sops.secrets = {
        grafana-admin-password = {
          owner = "grafana";
          group = "grafana";
          mode = "0400";
        };
        grafana-smtp-password = {
          owner = "grafana";
          group = "grafana";
          mode = "0400";
        };
      };
      services.grafana = {
        enable = true;
        dataDir = "/storage/grafana";
        provision = {
          enable = true;
          datasources = {
            settings = {
              datasources = [
                {
                  name = "Prometheus";
                  type = "prometheus";
                  access = "proxy";
                  url = "http://localhost:${toString config.services.prometheus.port}";
                  isDefault = true;
                }
              ];
            };
          };
        };
        settings = {
          server = {
            http_port = 3814;
          };
          smtp = {
            enabled = true;
            from_address = "grafana@lyte.dev";
            user = "grafana@lyte.dev";
            host = "smtp.mailgun.org:587";
            password = ''$__file{${config.sops.secrets.grafana-smtp-password.path}}'';
          };
          security = {
            admin_email = "daniel@lyte.dev";
            admin_user = "lytedev";
            admin_file = ''$__file{${config.sops.secrets.grafana-admin-password.path}}'';
          };
          # database = {
          # };
        };
      };
      networking.firewall.allowedTCPPorts = [
        9000
      ];
      services.caddy.virtualHosts."grafana.h.lyte.dev" = {
        extraConfig = ''reverse_proxy :${toString config.services.grafana.settings.server.http_port}'';
      };
    }
  ];

  # TODO: non-root processes and services that access secrets need to be part of
  # the 'keys' group
  # maybe this will fix plausible?

  # systemd.services.some-service = {
  #   serviceConfig.SupplementaryGroups = [ config.users.groups.keys.name ];
  # };
  # or
  # users.users.example-user.extraGroups = [ config.users.groups.keys.name ];

  # TODO: declarative directory quotas? for storage/$USER and /home/$USER

  environment.systemPackages = with pkgs; [
    aria2
    restic
    btrfs-progs
    zfs
    smartmontools
    htop
    bottom
    curl
    xh
  ];

  services.tailscale.useRoutingFeatures = "server";

  # https://github.com/NixOS/nixpkgs/blob/04af42f3b31dba0ef742d254456dc4c14eedac86/nixos/modules/services/misc/lidarr.nix#L72
  # services.lidarr = {
  #   enable = true;
  #   dataDir = "/storage/lidarr";
  # };

  # services.radarr = {
  #   enable = true;
  #   dataDir = "/storage/radarr";
  # };

  # services.sonarr = {
  #   enable = true;
  #   dataDir = "/storage/sonarr";
  # };

  # services.bazarr = {
  #   enable = true;
  #   listenPort = 6767;
  # };

  # networking.firewall.allowedTCPPorts = [9876 9877];
  # networking.firewall.allowedUDPPorts = [9876 9877];
  # networking.firewall.allowedUDPPortRanges = [
  #   {
  #     from = 27000;
  #     to = 27100;
  #   }
  # ];
}
