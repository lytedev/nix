{ ... }:
{
  config = {
    systemd.tmpfiles.rules = [
      "d /storage/jonland/ 0777 1000 1000 -"
      "d /storage/jonland/data/ 0777 1000 1000 -"
    ];

    virtualisation.oci-containers.containers.minecraft-jonland = {
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
        VERSION = "1.21.1";
        MEMORY = "8G";
        MAX_MEMORY = "16G";
        TYPE = "NEOFORGE";
        NEOFORGE_VERSION = "21.1.172";
        ALLOW_FLIGHT = "true";
        ENABLE_QUERY = "true";
        SEED = "-3495572360503818113";
      };
      environmentFiles = [ ];
      ports = [
        "26974:25565"
        "24454:24454/udp"
      ];
      volumes = [ "/storage/jonland/data:/data" ];
    };
    networking.firewall.allowedTCPPorts = [
      26974
      24454 # voice chat mod
    ];
    networking.firewall.allowedUDPPorts = [
      26974
      24454 # voice chat mod
    ];

  };
}
