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
  networking.hostName = "beefcake";

  imports = [
    # TODO: break these modules out someday maybe?
    {
      # hardware
      boot = {
        initrd.availableKernelModules = ["ehci_pci" "megaraid_sas" "usbhid" "uas" "sd_mod"];
        kernelModules = ["kvm-intel"];
        loader.systemd-boot.enable = true;
        loader.efi.canTouchEfiVariables = true;
      };

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/0747dcba-f590-42e6-89c8-6cb2f9114d64";
        fsType = "ext4";
        options = [
          "usrquota"
        ];
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/7E3C-9018";
        fsType = "vfat";
      };

      fileSystems."/storage" = {
        device = "/dev/disk/by-uuid/ea8258d7-54d1-430e-93b3-e15d33231063";
        fsType = "btrfs";
        options = [
          "compress=zstd:5"
          "space_cache=v2"
        ];
      };
    }
    {
      # sops secrets stuff
      sops = {
        defaultSopsFile = ../secrets/beefcake/secrets.yml;
        age = {
          sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
          keyFile = "/var/lib/sops-nix/key.txt";
          generateKey = true;
        };
        secrets = {
          # example-key = {
          #   # see these and other options' documentation here:
          #   # https://github.com/Mic92/sops-nix#set-secret-permissionowner-and-allow-services-to-access-it

          #   # set permissions:
          #   # mode = "0440";
          #   # owner = config.users.users.nobody.name;
          #   # group = config.users.users.nobody.group;

          #   # restart service when a secret changes or is newly initialized
          #   # restartUnits = [ "home-assistant.service" ];

          #   # symlink to certain directories
          #   path = "/var/lib/my-example-key/secrets.yaml";

          #   # for use as a user password
          #   # neededForUsers = true;
          # };

          # subdirectory
          # "myservice/my_subdir/my_secret" = { };

          "jland.env" = {
            path = "/var/lib/jland/jland.env";
            # TODO: would be cool to assert that it's correctly-formatted JSON? probably should be done in a pre-commit hook?
            mode = "0440";
            owner = config.users.users.daniel.name;
            group = config.users.groups.daniel.name;
          };

          "dawncraft.env" = {
            path = "/var/lib/dawncraft/dawncraft.env";
            # TODO: would be cool to assert that it's correctly-formatted JSON? probably should be done in a pre-commit hook?
            mode = "0440";
            owner = config.users.users.daniel.name;
            group = config.users.groups.daniel.name;
          };

          plausible-admin-password = {
            # TODO: path = "${config.systemd.services.plausible.serviceConfig.WorkingDirectory}/plausible-admin-password.txt";
            path = "/var/lib/plausible/plausible-admin-password";
            mode = "0440";
            owner = config.systemd.services.plausible.serviceConfig.User;
            group = config.systemd.services.plausible.serviceConfig.Group;
          };
          plausible-secret-key-base = {
            path = "/var/lib/plausible/plausible-secret-key-base";
            mode = "0440";
            owner = config.systemd.services.plausible.serviceConfig.User;
            group = config.systemd.services.plausible.serviceConfig.Group;
          };
          nextcloud-admin-password = {
            path = "/var/lib/nextcloud/admin-password";
            mode = "0440";
            # owner = config.services.nextcloud.serviceConfig.User;
            # group = config.services.nextcloud.serviceConfig.Group;
          };
        };
      };
    }
    {
      # nix binary cache
      services.nix-serve = {
        enable = true;
        secretKeyFile = "/var/cache-priv-key.pem";
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

      systemd.services."build-lytedev-flake" = {
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
          WorkingDirectory = "/home/daniel/.home/nightly-flake-builds";
          Type = "oneshot";
          User = "daniel"; # might have to run as me for git ssh access to the repo
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
        enable = true;
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
      services.caddy.virtualHosts."tailscale.vpn.h.lyte.dev" = {
        extraConfig = ''
          reverse_proxy http://localhost:${toString config.services.headscale.port}
        '';
      };
      networking.firewall.allowedUDPPorts = [3478];
    }
    {
      services.soju = {
        enable = true;
        listen = ["irc+insecure://:6667"];
      };
      networking.firewall.allowedTCPPorts = [
        6667
      ];
    }
    {
      # samba
      users.users.guest = {
        # used for anonymous samba access
        isSystemUser = true;
        group = "users";
        createHome = true;
      };
      users.users.scannerupload = {
        # used for scanner samba access
        isSystemUser = true;
        group = "users";
        createHome = true;
      };
      systemd.tmpfiles.rules = [
        "d /var/spool/samba 1777 root root -"
      ];
      services.samba-wsdd = {
        enable = true;
      };
      services.samba = {
        enable = true;
        openFirewall = true;
        securityType = "user";

        # not needed since I don't think I use printer sharing?
        # https://nixos.wiki/wiki/Samba#Printer_sharing
        # package = pkgs.sambaFull; # broken last I checked in nixpkgs?

        extraConfig = ''
          workgroup = WORKGROUP
          server string = beefcake
          netbios name = beefcake
          security = user
          #use sendfile = yes
          #max protocol = smb2
          # note: localhost is the ipv6 localhost ::1
          hosts allow = 100.64.0.0/10 192.168.0.0/16 127.0.0.1 localhost
          hosts deny = 0.0.0.0/0
          guest account = guest
          map to guest = never
          # load printers = yes
          # printing = cups
          # printcap name = cups
        '';
        shares = {
          libre = {
            path = "/storage/libre";
            browseable = "yes";
            "read only" = "no";
            "guest ok" = "yes";
            "create mask" = "0666";
            "directory mask" = "0777";
            # "force user" = "nobody";
            # "force group" = "users";
          };
          public = {
            path = "/storage/public";
            browseable = "yes";
            "read only" = "no";
            "guest ok" = "yes";
            "create mask" = "0664";
            "directory mask" = "0775";
            # "force user" = "nobody";
            # "force group" = "users";
          };
          family = {
            path = "/storage/family";
            browseable = "yes";
            "read only" = "no";
            "guest ok" = "no";
            "create mask" = "0660";
            "directory mask" = "0770";
            # "force user" = "nobody";
            # "force group" = "family";
          };
          scannerdocs = {
            path = "/storage/scannerdocs";
            browseable = "yes";
            "read only" = "no";
            "guest ok" = "no";
            "create mask" = "0600";
            "directory mask" = "0700";
            "valid users" = "scannerupload";
            "force user" = "scannerupload";
            "force group" = "users";
          };
          daniel = {
            path = "/storage/daniel";
            browseable = "yes";
            "read only" = "no";
            "guest ok" = "no";
            "create mask" = "0600";
            "directory mask" = "0700";
            # "force user" = "daniel";
            # "force group" = "users";
          };
          # printers = {
          #   comment = "All Printers";
          #   path = "/var/spool/samba";
          #   public = "yes";
          #   browseable = "yes";
          #   # to allow user 'guest account' to print.
          #   "guest ok" = "yes";
          #   writable = "no";
          #   printable = "yes";
          #   "create mode" = 0700;
          # };
        };
      };
    }
    {
      # nextcloud
      # users.users.nextcloud = {
      #   isSystemUser = true;
      #   createHome = false;
      #   group = "nextcloud";
      # };
    }
    {
      # plausible
      users.users.plausible = {
        isSystemUser = true;
        createHome = false;
        group = "plausible";
      };
      users.extraGroups = {
        "plausible" = {};
      };
      services.plausible = {
        # TODO: enable
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
      systemd.services.plausible = let
        cfg = config.services.plausible;
      in {
        serviceConfig.User = "plausible";
        serviceConfig.Group = "plausible";
        # since createdb is not gated behind postgres.setup, this breaks
        script = lib.mkForce ''
          # Elixir does not start up if `RELEASE_COOKIE` is not set,
          # even though we set `RELEASE_DISTRIBUTION=none` so the cookie should be unused.
          # Thus, make a random one, which should then be ignored.
          export RELEASE_COOKIE=$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 20)
          export ADMIN_USER_PWD="$(< $CREDENTIALS_DIRECTORY/ADMIN_USER_PWD )"
          export SECRET_KEY_BASE="$(< $CREDENTIALS_DIRECTORY/SECRET_KEY_BASE )"

          ${lib.optionalString (cfg.mail.smtp.passwordFile != null)
            ''export SMTP_USER_PWD="$(< $CREDENTIALS_DIRECTORY/SMTP_USER_PWD )"''}

          # setup
          ${
            if cfg.database.postgres.setup
            then "${cfg.package}/createdb.sh"
            else ""
          }
          ${cfg.package}/migrate.sh
          export IP_GEOLOCATION_DB=${pkgs.dbip-country-lite}/share/dbip/dbip-country-lite.mmdb
          ${cfg.package}/bin/plausible eval "(Plausible.Release.prepare() ; Plausible.Auth.create_user(\"$ADMIN_USER_NAME\", \"$ADMIN_USER_EMAIL\", \"$ADMIN_USER_PWD\"))"
          ${lib.optionalString cfg.adminUser.activate ''
            psql -d plausible <<< "UPDATE users SET email_verified=true where email = '$ADMIN_USER_EMAIL';"
          ''}

          exec plausible start
        '';
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
    }
    {
      # daniel augments
      users.groups.daniel.members = ["daniel"];
      users.groups.nixadmin.members = ["daniel"];
      users.users.daniel = {
        packages = [pkgs.weechat];
        extraGroups = [
          "nixadmin" # write access to /etc/nixos/ files
          "wheel" # sudo access
          "caddy" # write access to /storage/files.lyte.dev
          "users" # general users group
          "jellyfin" # write access to /storage/jellyfin
          "flanilla"
        ];
      };
    }
    {
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
      # hardware.opengl = {
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
      services.postgresql = {
        enable = true;
        ensureDatabases = [
          "daniel"
          "plausible"
          "nextcloud"
          # "atuin"
        ];
        ensureUsers = [
          {
            name = "daniel";
            ensureDBOwnership = true;
          }
          {
            name = "plausible";
            ensureDBOwnership = true;
          }
          {
            name = "nextcloud";
            ensureDBOwnership = true;
          }
          # {
          #   name = "atuin";
          #   ensureDBOwnership = true;
          # }
        ];
        dataDir = "/storage/postgres";
        enableTCPIP = true;

        package = pkgs.postgresql_15;

        # https://www.postgresql.org/docs/current/auth-pg-hba-conf.html
        authentication = pkgs.lib.mkOverride 10 ''
          #type database  user      auth-method    auth-options
          local all       postgres  peer           map=superuser_map
          local all       daniel    peer           map=superuser_map
          local sameuser  all       peer           map=superuser_map
          # local plausible plausible peer
          # local nextcloud nextcloud peer
          # local atuin     atuin     peer

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
        compression = "none"; # hoping for deduplication here?
        location = "/storage/postgres-backups";
        startAt = "*-*-* 03:00:00";
      };
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
        openssh.authorizedKeys.keys = [
          ""
        ];
      };

      networking.firewall.allowedTCPPorts = [
        64022
      ];
      networking.firewall.allowedUDPPorts = [
        64020
      ];
    }
    {
      # flanilla family minecraft server
      users.groups.flanilla = {};
      users.users.flanilla = {
        isSystemUser = true;
        createHome = false;
        group = "flanilla";
      };
    }
    {
      # restic backups
      users.users.restic = {
        # used for other machines to backup to
        isNormalUser = true;
        openssh.authorizedKeys.keys =
          [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJbPqzKB09U+i4Kqu136yOjflLZ/J7pYsNulTAd4x903 root@chromebox.h.lyte.dev"
          ]
          ++ config.users.users.daniel.openssh.authorizedKeys.keys;
      };
      # TODO: move previous backups over and put here
      # clickhouse and plausible analytics once they're up and running?
      services.restic.backups = let
        defaults = {
          passwordFile = "/root/restic-remotebackup-password";
          paths = [
            "/storage/files.lyte.dev"
            "/storage/daniel"
            "/storage/forgejo" # TODO: should maybe use configuration.nix's services.forgejo.dump ?
            "/storage/postgres-backups"

            # https://github.com/dani-garcia/vaultwarden/wiki/Backing-up-your-vault
            # specifically, https://github.com/dani-garcia/vaultwarden/wiki/Backing-up-your-vault#sqlite-database-files
            "/var/lib/bitwarden_rs" # does this need any sqlite preprocessing?

            # TODO: backup *arr configs?
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
            passwordFile = "/root/restic-localbackup-password";
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
            extraOptions = [
              "sftp.command='ssh daniel@n.benhaney.com -p 10022 -i /root/.ssh/id_ed25519 -s sftp'"
            ];
            repository = "sftp://daniel@n.benhaney.com://storage/backups/beefcake";
          };
      };
    }
    {
      services.caddy = {
        enable = true;
        email = "daniel@lyte.dev";
        adapter = "caddyfile";
        virtualHosts = {
          "dev.h.lyte.dev" = {
            extraConfig = ''
              reverse_proxy :8000
            '';
          };
          "files.lyte.dev" = {
            # TODO: customize the files.lyte.dev template?
            extraConfig = ''
              # @options {
              #   method OPTIONS
              # }
              # @corsOrigin {
              #   header_regexp Origin ^https?://([a-zA-Z0-9-]+\.)*lyte\.dev$
              # }
              header {
                Access-Control-Allow-Origin "{http.request.header.Origin}"
                Access-Control-Allow-Credentials true
                Access-Control-Allow-Methods *
                Access-Control-Allow-Headers *
                Vary Origin
                defer
              }
              # reverse_proxy shuwashuwa:8848 {
              #   header_down -Access-Control-Allow-Origin
              # }
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
      networking.firewall.allowedTCPPorts = [
        8000 # random development stuff
      ];
    }
    {
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
            # TODO: raise the log level
            LEVEL = "Debug";
          };
          ui = {
            THEMES = "catppuccin-mocha-sapphire,forgejo,arc-green,auto,pitchblack";
            DEFAULT_THEME = "catppuccin-mocha-sapphire";
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
          enable = true;
        };
        database = {
          # TODO: move to postgres?
          type = "sqlite3";
        };
      };
      # services.forgejo-actions-runner.instances.main = {
      #   # TODO: simple git-based automation would be dope? maybe especially for
      #   # mirroring to github super easy?
      #   enable = false;
      # };
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
      services.vaultwarden = {
        enable = true;
        config = {
          DOMAIN = "https://bw.lyte.dev";
          SIGNUPS_ALLOWED = "false";
          ROCKET_ADDRESS = "127.0.0.1";
          ROCKET_PORT = 8222;
        };
      };
      services.caddy.virtualHosts."bw.lyte.dev" = {
        extraConfig = ''reverse_proxy :${toString config.services.vaultwarden.config.ROCKET_PORT}'';
      };
    }
    {
      # TODO: make the client declarative? right now I think it's manually git
      # clone'd to /root
      systemd.services.deno-netlify-ddns-client = {
        serviceConfig.Type = "oneshot";
        path = with pkgs; [curl bash];
        environment = {
          NETLIFY_DDNS_RC_FILE = "/root/deno-netlify-ddns-client/.env";
        };
        script = ''
          bash /root/deno-netlify-ddns-client/netlify-ddns-client.sh
        '';
      };
      systemd.timers.deno-netlify-ddns-client = {
        wantedBy = ["timers.target"];
        partOf = ["deno-netlify-ddns-client.service"];
        timerConfig = {
          OnBootSec = "10sec";
          OnUnitActiveSec = "5min";
          Unit = "deno-netlify-ddns-client.service";
        };
      };
    }
    {
      services.atuin = {
        enable = true;
        database = {
          createLocally = true;
          # uri = "postgresql://atuin@localhost:5432/atuin";
        };
        openRegistration = false;
      };
      services.caddy.virtualHosts."atuin.h.lyte.dev" = {
        extraConfig = ''reverse_proxy :${toString config.services.atuin.port}'';
      };
    }
    {
      # jland minecraft server
      users.groups.jland = {
        gid = 982;
      };
      users.users.jland = {
        uid = 986;
        isSystemUser = true;
        createHome = false;
        group = "jland";
      };
      virtualisation.oci-containers.containers.minecraft-jland = {
        autoStart = false;

        # sending commands: https://docker-minecraft-server.readthedocs.io/en/latest/commands/
        image = "docker.io/itzg/minecraft-server";
        # user = "${toString config.users.users.jland.uid}:${toString config.users.groups.jland.gid}";
        extraOptions = [
          "--tty"
          "--interactive"
        ];
        environment = {
          EULA = "true";
          # UID = toString config.users.users.jland.uid;
          # GID = toString config.users.groups.jland.gid;
          STOP_SERVER_ANNOUNCE_DELAY = "20";
          TZ = "America/Chicago";
          VERSION = "1.20.1";
          MEMORY = "8G";
          MAX_MEMORY = "16G";
          TYPE = "FORGE";
          FORGE_VERSION = "47.1.3";
          ALLOW_FLIGHT = "true";
          ENABLE_QUERY = "true";

          MODPACK = "/data/origination-files/Server-Files-0.2.14.zip";

          # TYPE = "AUTO_CURSEFORGE";
          # CF_SLUG = "monumental-experience";
          # CF_FILE_ID = "4826863"; # 2.2.53

          # due to
          # Nov 02 13:45:22 beefcake minecraft-jland[2738672]: me.itzg.helpers.errors.GenericException: The modpack authors have indicated this file is not allowed for project distribution. Please download the client zip file from https://www.curseforge.com/minecraft/modpacks/monumental-experience and pass via CF_MODPACK_ZIP environment variable or place indownloads repo directory.
          # we must upload manually
          # CF_MODPACK_ZIP = "/data/origination-files/Monumental+Experience-2.2.53.zip";

          # ENABLE_AUTOPAUSE = "true"; # TODO: must increate or disable max-tick-time
          # May also have mod/loader incompatibilities?
          # https://docker-minecraft-server.readthedocs.io/en/latest/misc/autopause-autostop/autopause/
        };
        environmentFiles = [
          # config.sops.secrets."jland.env".path
        ];
        ports = ["26965:25565"];
        volumes = [
          "/storage/jland/data:/data"
          "/storage/jland/worlds:/worlds"
        ];
      };
      networking.firewall.allowedTCPPorts = [
        26965
      ];
    }
    {
      # dawncraft minecraft server
      systemd.tmpfiles.rules = [
        "d /storage/dawncraft/ 0770 1000 1000 -"
        "d /storage/dawncraft/data/ 0770 1000 1000 -"
        "d /storage/dawncraft/worlds/ 0770 1000 1000 -"
        "d /storage/dawncraft/downloads/ 0770 1000 1000 -"
      ];
      virtualisation.oci-containers.containers.minecraft-dawncraft = {
        autoStart = false;

        # sending commands: https://docker-minecraft-server.readthedocs.io/en/latest/commands/
        image = "docker.io/itzg/minecraft-server";
        extraOptions = [
          "--tty"
          "--interactive"
        ];
        environment = {
          EULA = "true";

          STOP_SERVER_ANNOUNCE_DELAY = "20";
          TZ = "America/Chicago";
          VERSION = "1.18.2";
          MEMORY = "8G";
          MAX_MEMORY = "32G";

          ALLOW_FLIGHT = "true";
          ENABLE_QUERY = "true";
          SERVER_PORT = "26968";
          QUERY_PORT = "26968";

          TYPE = "AUTO_CURSEFORGE";
          CF_SLUG = "dawn-craft";

          CF_EXCLUDE_MODS = "368398";
          CF_FORCE_SYNCHRONIZE = "true";
          # CF_FILE_ID = "5247696"; # 2.0.7 server
        };
        environmentFiles = [
          config.sops.secrets."dawncraft.env".path
        ];
        ports = ["26968:26968/tcp" "26968:26968/udp"];
        volumes = [
          "/storage/dawncraft/data:/data"
          "/storage/dawncraft/worlds:/worlds"
          "/storage/dawncraft/downloads:/downloads"
        ];
      };
      networking.firewall.allowedTCPPorts = [
        26968
      ];
    }
    {
      virtualisation.oci-containers.containers.minecraft-flanilla = {
        autoStart = true;

        image = "docker.io/itzg/minecraft-server";
        user = "${toString config.users.users.flanilla.uid}:${toString config.users.groups.flanilla.gid}";
        extraOptions = ["--tty" "--interactive"];
        environment = {
          EULA = "true";
          UID = toString config.users.users.flanilla.uid;
          GID = toString config.users.groups.flanilla.gid;
          STOP_SERVER_ANNOUNCE_DELAY = "20";
          TZ = "America/Chicago";
          VERSION = "1.20.4";
          OPS = "lytedev";
          MODE = "creative";
          DIFFICULTY = "peaceful";
          ONLINE_MODE = "false";
          MEMORY = "8G";
          MAX_MEMORY = "16G";
          ALLOW_FLIGHT = "true";
          ENABLE_QUERY = "true";
          ENABLE_COMMAND_BLOCK = "true";
        };

        environmentFiles = [
          # config.sops.secrets."flanilla.env".path
        ];

        ports = ["26966:25565"];

        volumes = [
          "/storage/flanilla/data:/data"
          "/storage/flanilla/worlds:/worlds"
        ];
      };
      networking.firewall.allowedTCPPorts = [
        26966
      ];
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

  # TODO: directory attributes for /storage subdirectories?
  # example: user daniel should be able to write to /storage/files.lyte.dev and
  # caddy should be able to serve it

  # TODO: declarative directory quotas? for storage/$USER and /home/$USER

  # TODO: would be nice to get ALL the storage stuff declared in here
  # should I be using btrfs subvolumes? can I capture file ownership, perimssions, and ACLs?

  virtualisation.oci-containers.backend = "podman";
  environment.systemPackages = with pkgs; [
    linuxquota
    htop
    bottom
    curl
    xh
  ];
  services.tailscale.useRoutingFeatures = "server";
  services.openssh = {
    listenAddresses = [
      {
        addr = "0.0.0.0";
        port = 64022;
      }
      {
        addr = "0.0.0.0";
        port = 22;
      }
    ];
  };

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

  networking.firewall.allowedTCPPorts = [9876 9877];
  networking.firewall.allowedUDPPorts = [9876 9877];
  networking.firewall.allowedUDPPortRanges = [
    {
      from = 27000;
      to = 27100;
    }
  ];

  home-manager.users.daniel.home.stateVersion = "24.05";
  system.stateVersion = "22.05";
}
