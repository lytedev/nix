{
  config,
  pkgs,
  ...
}:
let
  dataDir = "/var/lib/mmrelay";

  # Dedicated system user the container runs as. Pinned uid/gid so the host data
  # dir + the sops credentials secret can be owned by it. podman --user needs a
  # numeric uid here because names resolve in the container's passwd, not the
  # host's (the image's own "mmrelay" is uid 1000 = daniel on beefcake).
  mmrelayUid = 945;
  mmrelayGid = 945;

  # Non-secret config. Matrix homeserver/user/token come from credentials.json
  # (sops) instead, so nothing secret lands in the nix store.
  # EDIT the room id + meshnet name before deploy.
  configFile = (pkgs.formats.yaml { }).generate "mmrelay-config.yaml" {
    matrix_rooms = [
      {
        id = "!FIQbwRW4YEcuaPoDnq:lyte.dev"; # Meshtastic Bridge room
        meshtastic_channel = 0; # primary channel
      }
    ];
    meshtastic = {
      connection_type = "tcp";
      host = "127.0.0.1"; # meshtasticd on this host (container uses host networking)
      port = 4403;
      meshnet_name = "lyte family mesh";
      broadcast_enabled = true;
    };
    matrix = {
      # E2EE off for v1 → the bridge room must be UNENCRYPTED. Enabling E2EE
      # later needs a populated matrix/store and a device-scoped credentials.json.
      e2ee.enabled = false;
    };
    logging.level = "info";
  };
in
{
  # mmrelay — bridges the meshtasticd virtual node (localhost:4403) to a Matrix
  # room so off-mesh family (Daniel's wife, via Element) can read + send on the
  # Meshtastic channel. Not in nixpkgs, so run the official container (beefcake
  # already has podman via lyte.podman). Third/last piece of the bridge stack;
  # depends on ./meshtasticd.nix (#585) and ./mosquitto.nix (#584).
  #
  # REQUIRED before deploy:
  #  1. Edit the room id + meshnet_name above.
  #  2. Provide Matrix credentials via sops as JSON (from `mmrelay auth login`,
  #     or hand-built from an access token):
  #       sops secrets/beefcake/secrets.yml
  #       # mmrelay-credentials: |
  #       #   {"homeserver":"https://matrix.lyte.dev","user_id":"@meshbridge:lyte.dev",
  #       #    "access_token":"<token>","device_id":"<device>"}
  #  3. The bridge room must be unencrypted (E2EE disabled in v1).

  users.users.mmrelay = {
    isSystemUser = true;
    group = "mmrelay";
    uid = mmrelayUid;
  };
  users.groups.mmrelay.gid = mmrelayGid;

  # credentials.json — owned by mmrelay so the container (running as that uid)
  # can read it.
  sops.secrets."mmrelay-credentials" = {
    owner = "mmrelay";
    group = "mmrelay";
    mode = "0400";
  };

  systemd.tmpfiles.settings."10-mmrelay" = {
    "${dataDir}" = {
      "d" = {
        mode = "0700";
        user = "mmrelay";
        group = "mmrelay";
      };
    };
    "${dataDir}/matrix" = {
      "d" = {
        mode = "0700";
        user = "mmrelay";
        group = "mmrelay";
      };
    };
    "${dataDir}/database" = {
      "d" = {
        mode = "0700";
        user = "mmrelay";
        group = "mmrelay";
      };
    };
  };

  virtualisation.oci-containers.containers.mmrelay = {
    # TODO: pin to a released tag/digest instead of :latest.
    image = "ghcr.io/jeremiah-k/mmrelay:latest";
    autoStart = true;
    # Run as the dedicated mmrelay user (numeric — podman resolves names in the
    # container, not on the host) so it reads the mmrelay-owned credentials
    # secret and writes the mmrelay-owned data dir.
    user = "${toString mmrelayUid}:${toString mmrelayGid}";
    environment.MMRELAY_HOME = "/data";
    volumes = [
      "${dataDir}:/data"
      "${configFile}:/data/config.yaml:ro"
      "${config.sops.secrets."mmrelay-credentials".path}:/data/matrix/credentials.json:ro"
    ];
    # Host networking so the container reaches meshtasticd on 127.0.0.1:4403
    # without exposing that API or touching the firewall.
    extraOptions = [ "--network=host" ];
  };
}
