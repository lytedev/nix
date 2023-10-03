# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').
{
  outputs,
  modulesPath,
  config,
  pkgs,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    outputs.nixosModules.intel
  ];

  boot.initrd.availableKernelModules = ["ehci_pci" "megaraid_sas" "usbhid" "uas" "sd_mod"];
  boot.kernelModules = ["kvm-intel"];

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

  services.nix-serve = {
    enable = true;
    secretKeyFile = "/var/cache-priv-key.pem";
  };

  services.api-lyte-dev = rec {
    enable = true;
    port = 5757;
    stateDir = "/var/lib/api-lyte-dev";
    configFile = config.sops.secrets."api.lyte.dev".path;
    user = "api-lyte-dev";
    group = user;
  };

  systemd.services.api-lyte-dev.environment.LOG_LEVEL = "debug";

  sops = {
    defaultSopsFile = ../../secrets/beefcake/secrets.yml;
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

      "api.lyte.dev" = {
        path = "${config.services.api-lyte-dev.stateDir}/secrets.json";
        # TODO: would be cool to assert that it's correctly-formatted JSON?
        mode = "0440";
        owner = config.services.api-lyte-dev.user;
        group = config.services.api-lyte-dev.group;
      };

      plausible-admin-password = {
        # TODO: path = "${config.systemd.services.plausible.serviceConfig.WorkingDirectory}/plausible-admin-password.txt";
        path = "/var/lib/plausible/plausible-admin-password";
        mode = "0440";
        owner = config.systemd.services.plausible.serviceConfig.User;
        group = config.systemd.services.plausible.serviceConfig.Group;
      };
      plausible-erlang-cookie = {
        path = "/var/lib/plausible/plausible-erlang-cookie";
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
    };
  };

  # TODO: non-root processes and services that access secrets need to be part of
  # the 'keys' group

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

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  systemd.tmpfiles.rules = [
    "d /var/spool/samba 1777 root root -"
  ];

  networking.hostName = "beefcake";

  users.extraGroups = {
    "plausible" = {};
    "lytedev" = {};
  };
  users.groups.daniel.members = ["daniel"];
  users.groups.nixadmin.members = ["daniel"];

  users.users.daniel = {
    extraGroups = [
      "nixadmin" # write access to /etc/nixos/ files
      "wheel" # sudo access
      "caddy" # write access to /storage/files.lyte.dev
      "users" # general users group
      "jellyfin" # write access to /storage/jellyfin
    ];
  };

  users.users.lytedev = {
    # for running my services and applications and stuff
    isNormalUser = true;
    openssh.authorizedKeys.keys = config.users.users.daniel.openssh.authorizedKeys.keys;
    group = "lytedev";
  };

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

  users.users.restic = {
    # used for other machines to backup to
    isNormalUser = true;
    openssh.authorizedKeys.keys =
      [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJbPqzKB09U+i4Kqu136yOjflLZ/J7pYsNulTAd4x903 root@chromebox.h.lyte.dev"
      ]
      ++ config.users.users.daniel.openssh.authorizedKeys.keys;
  };

  users.users.guest = {
    # used for anonymous samba access
    isSystemUser = true;
    group = "users";
    createHome = true;
  };

  users.users.plausible = {
    # used for anonymous samba access
    isSystemUser = true;
    createHome = false;
    group = "plausible";
  };

  environment.systemPackages = [pkgs.linuxquota];

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

  services.caddy = {
    enable = true;
    adapter = "caddyfile";
    # acmeCA = "https://acme-staging-v02.api.letsencrypt.org/directory";
    # TODO: there are some hardcoded ports here!
    # https://github.com/NixOS/nixpkgs/blob/04af42f3b31dba0ef742d254456dc4c14eedac86/nixos/modules/services/misc/lidarr.nix#L72
    configFile = pkgs.writeText "Caddyfile" ''
      video.lyte.dev {
        reverse_proxy :8096
      }

      # lidarr.h.lyte.dev {
        # reverse_proxy :8686
      # }

      # radarr.h.lyte.dev {
        # reverse_proxy :7878
      # }

      # sonarr.h.lyte.dev {
        # reverse_proxy :8989
      # }

      # bazarr.h.lyte.dev {
        # reverse_proxy :${toString config.services.bazarr.listenPort}
      # }

      bw.lyte.dev {
        reverse_proxy :${toString config.services.vaultwarden.config.ROCKET_PORT}
      }

      api.lyte.dev {
        reverse_proxy :${toString config.services.api-lyte-dev.port}
      }

      a.lyte.dev {
        reverse_proxy :${toString config.services.plausible.server.port}
      }

      git.lyte.dev {
        reverse_proxy :${toString config.services.gitea.settings.server.HTTP_PORT}
      }

      files.lyte.dev {
        file_server browse {
          root /storage/files.lyte.dev
        }
      }

      nix.h.lyte.dev {
        reverse_proxy :${toString config.services.nix-serve.port}
      }

      # proxy everything else to chromebox
      :80 {
        reverse_proxy 10.0.0.5:80
      }

      :443 {
        reverse_proxy 10.0.0.5:443
      }
    '';
  };

  services.vaultwarden = {
    enable = true;
    config = {
      DOMAIN = "https://bw.lyte.dev";
      SIGNUPS_ALLOWED = "false";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
    };
  };

  services.gitea = {
    enable = true;
    appName = "git.lyte.dev";
    stateDir = "/storage/gitea";
    settings = {
      server = {
        ROOT_URL = "https://git.lyte.dev";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3088;
        DOMAIN = "git.lyte.dev";
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
        THEMES = "catppuccin-mocha-sapphire,gitea,arc-green,auto,pitchblack";
        DEFAULT_THEME = "catppuccin-mocha-sapphire";
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

  # TODO: ensure we're not doing the same dumb thing we were doing on the old host and eating storage
  services.clickhouse.enable = true;

  systemd.services.plausible.serviceConfig.User = "plausible";
  systemd.services.plausible.serviceConfig.Group = "plausible";

  services.plausible = {
    # TODO: enable
    enable = false;
    releaseCookiePath = config.sops.secrets.plausible-erlang-cookie.path;
    database = {
      clickhouse.setup = true;
      postgres = {
        setup = false;
        dbname = "plausible";
      };
    };
    server = {
      baseUrl = "http://beefcake.hare-cod.ts.net:8899";
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

  services.postgresql = {
    enable = true;
    ensureDatabases = ["daniel" "plausible"];
    ensureUsers = [
      {
        name = "daniel";
        ensurePermissions = {
          "DATABASE daniel" = "ALL PRIVILEGES";
        };
      }
      {
        name = "plausible";
        ensurePermissions = {
          "DATABASE plausible" = "ALL PRIVILEGES";
        };
      }
    ];
    dataDir = "/storage/postgres";
    enableTCPIP = true;

    package = pkgs.postgresql_15;

    authentication = pkgs.lib.mkOverride 10 ''
      #type database  DBuser    auth-method
      local all       postgres  peer map=superuser_map
      local all       daniel    peer map=superuser_map
      local sameuser  all       peer map=superuser_map
      local plausible plausible peer map=superuser_map

      # lan ipv4
      host  all       all     10.0.0.0/24   trust

      # tailnet ipv4
      host       all       all     100.64.0.0/10 trust
    '';

    identMap = ''
      # ArbitraryMapName systemUser DBUser
        superuser_map    root       postgres
        superuser_map    postgres   postgres
        superuser_map    daniel     postgres
        # Let other names login as themselves
        superuser_map   /^(.*)$    \1
    '';
  };

  services.postgresqlBackup = {
    enable = true;
    backupAll = true;
    compression = "none"; # hoping for deduplication here?
    location = "/storage/postgres-backups";
    startAt = "*-*-* 03:00:00";
  };

  services.tailscale = {
    useRoutingFeatures = "server";
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    # uses port 8096 by default, configurable from admin UI
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

  services.lidarr = {
    enable = true;
    dataDir = "/storage/lidarr";
  };

  services.radarr = {
    enable = true;
    dataDir = "/storage/radarr";
  };

  services.sonarr = {
    enable = true;
    dataDir = "/storage/sonarr";
  };

  services.bazarr = {
    enable = true;
    listenPort = 6767;
  };

  services.samba-wsdd.enable = true;

  services.samba = {
    enable = true;
    openFirewall = true;
    securityType = "user";
    package = pkgs.sambaFull;

    extraConfig = ''
      workgroup = WORKGROUP
      server string = beefcake
      netbios name = beefcake
      security = user
      #use sendfile = yes
      #max protocol = smb2
      # note: localhost is the ipv6 localhost ::1
      hosts allow = 10. 192.168.0. 127.0.0.1 localhost
      hosts deny = 0.0.0.0/0
      guest account = nobody
      map to guest = bad user
      load printers = yes
      printing = cups
      printcap name = cups
    '';
    shares = {
      libre = {
        path = "/storage/libre";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0666";
        "directory mask" = "0777";
        "force user" = "nobody";
        "force group" = "users";
      };
      public = {
        path = "/storage/public";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0664";
        "directory mask" = "0775";
        "force user" = "nobody";
        "force group" = "users";
      };
      family = {
        path = "/storage/family";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0664";
        "directory mask" = "0775";
        "force user" = "nobody";
        "force group" = "family";
      };
      daniel = {
        path = "/storage/daniel";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0640";
        "directory mask" = "0750";
        "force user" = "daniel";
        "force group" = "users";
      };
      printers = {
        comment = "All Printers";
        path = "/var/spool/samba";
        public = "yes";
        browseable = "yes";
        # to allow user 'guest account' to print.
        "guest ok" = "yes";
        writable = "no";
        printable = "yes";
        "create mode" = 0700;
      };
    };
  };

  # paths:
  # TODO: move previous backups over and put here
  # clickhouse and plausible analytics once they're up and running?

  services.restic.backups = rec {
    local = {
      initialize = true;
      passwordFile = "/root/restic-localbackup-password";
      paths = [
        "/storage/files.lyte.dev"
        "/storage/daniel"
        "/storage/gitea" # TODO: should maybe use configuration.nix's services.gitea.dump ?
        "/var/lib/bitwarden_rs" # does this need any sqlite preprocessing?
        # https://github.com/dani-garcia/vaultwarden/wiki/Backing-up-your-vault
        # specifically, https://github.com/dani-garcia/vaultwarden/wiki/Backing-up-your-vault#sqlite-database-files
        # TODO: backup lidarr/radarr configs?

        "/storage/postgres-backups"
      ];
      exclude = [];
      repository = "/storage/backups/local";
    };
    rascal = {
      initialize = true;
      extraOptions = [
        "sftp.command='ssh beefcake@rascal -i /root/.ssh/id_ed25519 -s sftp'"
      ];
      passwordFile = local.passwordFile;
      paths = local.paths;
      repository = "sftp://beefcake@rascal://storage/backups/beefcake";
      timerConfig = {
        OnCalendar = "04:45";
      };
    };
    # TODO: add ruby?
    benland = {
      initialize = true;
      extraOptions = [
        "sftp.command='ssh daniel@n.benhaney.com -p 10022 -i /root/.ssh/id_ed25519 -s sftp'"
      ];
      passwordFile = local.passwordFile;
      paths = local.paths;
      repository = "sftp://daniel@n.benhaney.com://storage/backups/beefcake";
      timerConfig = {
        OnCalendar = "04:45";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    80 # http (caddy)
    443 # https (caddy)
    # 5357 # ???
    22 # ssh
    64022 # ssh (for ben?)
  ];
  networking.firewall.allowedUDPPorts = [
    # 53 # DNS
    # 3702 # ???
    64020 # mosh (for ben?)
  ];
  networking.firewall.allowedUDPPortRanges = [
    {
      # mosh
      from = 60000;
      to = 60010;
    }
  ];

  networking.firewall = {
    enable = true;
    allowPing = true;
  };

  system.stateVersion = "22.05";
}
