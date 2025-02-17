{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.virtualisation.oci-containers.backend == "podman") {
    environment = {
      systemPackages = with pkgs; [
        podman-compose
      ];
    };

    virtualisation = {
      podman = {
        dockerCompat = true;
        dockerSocket.enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };

      oci-containers = {
        # backend = "podman";
      };
    };

    networking = {
      extraHosts = ''
        127.0.0.1 host.docker.internal
        ::1 host.docker.internal
        127.0.0.1 host.containers.internal
        ::1 host.containers.internal
      '';
    };
  };
}
