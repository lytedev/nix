{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.virtualisation.podman.enable {
    environment = {
      systemPackages = with pkgs; [
        podman-compose
      ];
    };

    virtualisation = {
      podman = {
        dockerCompat = config.virtualisation.podman.enable;
        dockerSocket.enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };

      oci-containers = {
        backend = "podman";
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
