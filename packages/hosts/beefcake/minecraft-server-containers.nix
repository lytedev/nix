{
  imports = [
    # jland minecraft server
    /*
      (
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
              ## UID = toString config.users.users.jland.uid;
              ## GID = toString config.users.groups.jland.gid;
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

              ## TYPE = "AUTO_CURSEFORGE";
              ## CF_SLUG = "monumental-experience";
              ## CF_FILE_ID = "4826863"; # 2.2.53

              ## due to
              ## Nov 02 13:45:22 beefcake minecraft-jland[2738672]: me.itzg.helpers.errors.GenericException: The modpack authors have indicated this file is not allowed for project distribution. Please download the client zip file from https://www.curseforge.com/minecraft/modpacks/monumental-experience and pass via CF_MODPACK_ZIP environment variable or place indownloads repo directory.
              ## we must upload manually
              ## CF_MODPACK_ZIP = "/data/origination-files/Monumental+Experience-2.2.53.zip";

              ## ENABLE_AUTOPAUSE = "true"; # TODO: must increate or disable max-tick-time
              ## May also have mod/loader incompatibilities?
              ## https://docker-minecraft-server.readthedocs.io/en/latest/misc/autopause-autostop/autopause/
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
      )
    */

    {
      # jonland minecraft server
      systemd.tmpfiles.rules = [
        "d /storage/jonland/ 0777 1000 1000 -"
        "d /storage/jonland/data/ 0777 1000 1000 -"
      ];
      virtualisation.oci-containers.containers.minecraft-jonland = {
        autoStart = true;

        # sending commands: https://docker-minecraft-server.readthedocs.io/en/latest/commands/
        image = "docker.io/itzg/minecraft-server";
        # user = "${toString config.users.users.jonland.uid}:${toString config.users.groups.jonland.gid}";
        extraOptions = [
          "--tty"
          "--interactive"
        ];
        environment = {
          EULA = "true";
          DISABLE_HEALTHCHECK = "true";
          ## UID = toString config.users.users.jonland.uid;
          ## GID = toString config.users.groups.jonland.gid;
          STOP_SERVER_ANNOUNCE_DELAY = "20";
          TZ = "America/Chicago";
          VERSION = "1.21.1";
          MEMORY = "8G";
          MAX_MEMORY = "16G";
          TYPE = "NEOFORGE";
          NEOFORGE_VERSION = "21.1.145";
          ALLOW_FLIGHT = "true";
          ENABLE_QUERY = "true";

          MODPACK = "/data/origination-files/shadic_minecraft.zip";

          ## TYPE = "AUTO_CURSEFORGE";
          ## CF_SLUG = "monumental-experience";
          ## CF_FILE_ID = "4826863"; # 2.2.53

          ## due to
          ## Nov 02 13:45:22 beefcake minecraft-jland[2738672]: me.itzg.helpers.errors.GenericException: The modpack authors have indicated this file is not allowed for project distribution. Please download the client zip file from https://www.curseforge.com/minecraft/modpacks/monumental-experience and pass via CF_MODPACK_ZIP environment variable or place indownloads repo directory.
          ## we must upload manually
          ## CF_MODPACK_ZIP = "/data/origination-files/Monumental+Experience-2.2.53.zip";

          ## ENABLE_AUTOPAUSE = "true"; # TODO: must increate or disable max-tick-time
          ## May also have mod/loader incompatibilities?
          ## https://docker-minecraft-server.readthedocs.io/en/latest/misc/autopause-autostop/autopause/
        };
        environmentFiles = [
          # config.sops.secrets."jland.env".path
        ];
        ports = [
          "26974:25565"
          "24454:24454/udp"
        ];
        volumes = [
          "/storage/jonland/data:/data"
        ];
      };
      networking.firewall.allowedTCPPorts = [
        26974
        24454 # voice chat mod?
      ];
      networking.firewall.allowedUDPPorts = [
        26974
        24454 # voice chat mod?
      ];

    }

    {
      # dawncraft minecraft server
      /*
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
      */
    }

    (
      let
        port = 26969;
        dir = "/storage/flanilla";
        user = "flanilla";
      in
      # uid = config.users.users.flanilla.uid;
      # gid = config.users.groups.flanilla.gid;
      {
        # flanilla family minecraft server
        users.groups.${user} = { };
        users.users.${user} = {
          isSystemUser = true;
          createHome = false;
          home = dir;
          group = user;
          linger = true;
        };
        virtualisation.oci-containers.containers.minecraft-flanilla = {
          autoStart = false;

          environmentFiles = [
            # config.sops.secrets."jland.env".path
          ];
          image = "docker.io/itzg/minecraft-server";
          # user = "${toString uid}:${toString gid}";
          extraOptions = [
            "--tty"
            "--interactive"
          ];
          environment = {
            EULA = "true";
            MOTD = "Flanilla Survival! Happy hunting!";
            # UID = toString uid;
            # GID = toString gid;
            STOP_SERVER_ANNOUNCE_DELAY = "20";
            TZ = "America/Chicago";
            VERSION = "1.21";
            OPS = "lytedev";
            MODE = "survival";
            DIFFICULTY = "easy";
            ONLINE_MODE = "false";
            MEMORY = "8G";
            MAX_MEMORY = "16G";
            ALLOW_FLIGHT = "true";
            ENABLE_QUERY = "true";
            ENABLE_COMMAND_BLOCK = "true";
          };
          ports = [ "${toString port}:25565" ];

          volumes = [
            "${dir}/data:/data"
            "${dir}/worlds:/worlds"
          ];
        };
        systemd.services.podman-minecraft-flanilla.serviceConfig = {
          User = user;
          Group = user;
        };
        systemd.tmpfiles.settings = {
          "10-${user}-survival" = {
            "${dir}/data" = {
              "d" = {
                mode = "0770";
                user = user;
                group = user;
              };
            };
            "${dir}/worlds" = {
              "d" = {
                mode = "0770";
                user = user;
                group = user;
              };
            };
          };
        };
        services.restic.commonPaths = [ dir ];
        networking.firewall.allowedTCPPorts = [
          port
        ];
      }
    )

    (
      { lib, ... }:
      let
        port = 26968;
        dir = "/storage/flanilla-creative";
        user = "flanilla";
      in
      # uid = config.users.users.flanilla.uid;
      # gid = config.users.groups.flanilla.gid;
      {
        # flanilla family minecraft server
        users.groups.${user} = { };
        users.users.${user} = {
          isSystemUser = true;
          createHome = false;
          home = lib.mkForce dir;
          group = user;
          # linger = true;
        };
        virtualisation.oci-containers.containers.minecraft-flanilla-creative = {
          autoStart = false;
          image = "docker.io/itzg/minecraft-server";
          # user = "${toString uid}:${toString gid}";
          extraOptions = [
            "--tty"
            "--interactive"
          ];
          environment = {
            EULA = "true";
            MOTD = "Flanilla Creative! Have fun building!";
            # UID = toString uid;
            # GID = toString gid;
            STOP_SERVER_ANNOUNCE_DELAY = "20";
            TZ = "America/Chicago";
            VERSION = "1.21";
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
          ports = [ "${toString port}:25565" ];
          volumes = [
            "${dir}/data:/data"
            "${dir}/worlds:/worlds"
          ];
        };
        # systemd.services.podman-minecraft-flanilla-creative.serviceConfig = {
        #   User = user;
        #   Group = user;
        # };
        systemd.tmpfiles.settings = {
          "10-${user}-creative" = {
            "${dir}/data" = {
              "d" = {
                mode = "0770";
                user = user;
                group = user;
              };
            };
            "${dir}/worlds" = {
              "d" = {
                mode = "0770";
                user = user;
                group = user;
              };
            };
          };
        };
        services.restic.commonPaths = [ dir ];
        networking.firewall.allowedTCPPorts = [
          port
        ];
      }
    )
  ];
}
