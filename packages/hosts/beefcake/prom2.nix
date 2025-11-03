{ ... }:
let
  server_name = "prom2";
  dir = "/storage/${server_name}";
  port = 26989;
in
{
  config = {
    systemd.tmpfiles.rules = [
      "d ${dir}/ 0777 1000 1000 -"
      "d ${dir}/data/ 0777 1000 1000 -"
    ];

    virtualisation.oci-containers.containers."minecraft-${server_name}" = {
      autoStart = true;

      # sending commands: https://docker-minecraft-server.readthedocs.io/en/latest/commands/

      image = "docker.io/itzg/minecraft-server";
      extraOptions = [
        "--tty"
        "--interactive"
      ];
      environment = {
        EULA = "true";
        DISABLE_HEALTHCHECK = "true";
        STOP_SERVER_ANNOUNCE_DELAY = "20";
        TZ = "America/Chicago";
        VERSION = "1.20.1";
        MEMORY = "8G";
        MAX_MEMORY = "32G";
        TYPE = "MODRINTH";
        MODRINTH_MODPACK = "prominence-2-fabric";
        MODRINTH_PROJECTS = "simple-voice-chat,distanthorizons:beta";
        MODRINTH_EXCLUDE_FILES = "welcomescreen-fabric-1.0.0-1.20.1.jar";
        ALLOW_FLIGHT = "true";
        ENABLE_QUERY = "true";
      };
      environmentFiles = [ ];
      ports = [
        "${toString port}:25565"
        "24454:24454/udp"
      ];
      volumes = [ "${dir}/data:/data" ];
    };
    networking.firewall.allowedTCPPorts = [
      port
      24454 # voice chat mod
    ];
    networking.firewall.allowedUDPPorts = [
      port
      24454 # voice chat mod
    ];

  };
}
