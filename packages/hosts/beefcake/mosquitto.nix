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
      }
    ];
  };

  # Open the MQTT port only on trusted interfaces — home LAN and the tailnet.
  # Never on the public internet (beefcake's eno1 sits behind home NAT and 1883
  # is not port-forwarded).
  networking.firewall.interfaces."eno1".allowedTCPPorts = [ 1883 ];
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 1883 ];
}
