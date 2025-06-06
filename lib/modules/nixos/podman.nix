{
  pkgs,
  config,
  lib,
  ...
}:
{
  options = {
    podman.enable = lib.mkEnableOption "Enable podman and associated general NixOS defaults";
  };

  config = lib.mkIf config.podman.enable {
    environment = {
      systemPackages = with pkgs; [
        podman-tui
        podman-compose
      ];
    };

    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
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
