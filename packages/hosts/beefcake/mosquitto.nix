{ config, ... }:
{
  # Self-hosted MQTT broker for Meshtastic.
  #
  # Bridges the RF mesh to MQTT so off-mesh clients (a Matrix bridge, web
  # dashboards, family members without a radio) can follow and participate in
  # the family channel. A Meshtastic gateway node with Uplink+Downlink enabled
  # publishes/subscribes here; see https://meshtastic.org/docs/configuration/module/mqtt/
  #
  # Exposure: bound to all interfaces but the firewall only opens 1883 on the
  # home LAN (eno1, behind NAT — not internet-reachable) and the tailnet
  # (tailscale0). The phone MQTT client-proxy for the nRF52 T-Echo reaches this
  # over Tailscale; no public listener / TLS needed. Add a TLS listener on 8883
  # later if off-tailnet phone access is wanted.
  #
  # REQUIRED before deploy: add the broker password to the beefcake sops file:
  #   sops secrets/beefcake/secrets.yml
  #   # then add a line:  mosquitto-meshtastic-password: <a-strong-password>
  # Use the same username (meshtastic) + password in each Meshtastic node's
  # MQTT module and in any bridge/client.

  sops.secrets."mosquitto-meshtastic-password" = {
    owner = "mosquitto";
    group = "mosquitto";
    mode = "0400";
  };

  # Dedicated account for the local meshtasticd virtual node (./meshtasticd.nix).
  #
  # WHY A SEPARATE USER: Meshtastic firmware stores mqtt.password in a fixed
  # protobuf field with nanopb `max_size:32` — at most 31 usable bytes plus the
  # NUL terminator. A 32+ char password is silently rejected on the node: the
  # whole set_module_config admin message fails to decode, the MQTT module keeps
  # its default public-server creds (meshdev/large4cats), and the broker rejects
  # it "not authorised" — with no error surfaced to the meshtastic CLI. See
  # https://github.com/meshtastic/protobufs/blob/master/meshtastic/module_config.options
  # (MQTTConfig.password max_size:32). A dedicated account lets the shared
  # `meshtastic` user (web dashboards, other clients) keep a strong password
  # while this credential stays within the firmware's limit.
  #
  # INVARIANT: mosquitto-meshtasticd-password MUST be <= 31 characters. The
  # provisioning oneshot in ./meshtasticd.nix asserts this at deploy time.
  sops.secrets."mosquitto-meshtasticd-password" = {
    owner = "mosquitto";
    group = "mosquitto";
    mode = "0400";
  };

  services.mosquitto = {
    enable = true;
    # Retain messages and queued state across restarts.
    persistence = true;
    listeners = [
      {
        port = 1883;
        # Listen on all interfaces; access is restricted by the firewall below.
        settings.allow_anonymous = false;
        users.meshtastic = {
          passwordFile = config.sops.secrets."mosquitto-meshtastic-password".path;
          # Single home broker: allow this account full pub/sub on all topics.
          acl = [ "readwrite #" ];
        };
        # Local meshtasticd virtual node — own account, password <= 31 chars (see above).
        users.meshtasticd = {
          passwordFile = config.sops.secrets."mosquitto-meshtasticd-password".path;
          acl = [ "readwrite #" ];
        };
      }
    ];
  };

  # Open the MQTT port only on trusted interfaces — home LAN and the tailnet.
  # Never on the public internet (beefcake's eno1 sits behind home NAT and 1883
  # is not port-forwarded).
  networking.firewall.interfaces."eno1".allowedTCPPorts = [ 1883 ];
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 1883 ];
}
