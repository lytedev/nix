{
  config,
  pkgs,
  lib,
  ...
}:
let
  # LoRa region for the virtual node. Must match the rest of your mesh.
  # (US, EU_433, EU_868, ANZ, etc. — see Meshtastic LoRa region list.)
  region = "US";

  # Local broker (Mosquitto runs on this same host — see ./mosquitto.nix).
  mqttHost = "127.0.0.1";
  mqttUser = "meshtastic";
in
{
  # Radio-less Meshtastic virtual node.
  #
  # beefcake has no physical radio, and the real nodes travel with Daniel. This
  # daemon runs in simulation mode (Lora.Module = "sim") and joins the family
  # channel purely over MQTT via the local Mosquitto broker — becoming a full
  # participant node whenever a carried node is bridging RF<->MQTT (T-Echo via
  # phone client-proxy over Tailscale, or T-Deck on WiFi). It exposes the
  # Meshtastic client API on TCP 4403 (localhost only — not firewalled open),
  # which the mmrelay Matrix bridge connects to (separate PR).
  #
  # config.yaml only carries hardware/sim settings; the channel + MQTT module
  # are node-state, applied once via the `meshtastic` CLI by the provisioning
  # oneshot below. See https://meshtastic.org/docs/configuration/module/mqtt/
  #
  # REQUIRED before deploy: add the family channel share-URL to sops (it encodes
  # the channel name + PSK, so it is secret):
  #   sops secrets/beefcake/secrets.yml
  #   # meshtastic-channel-url: "https://meshtastic.org/e/#<your-channel-set>"
  # Get it from the app: Channels -> (share) -> copy URL / "Add all channels".
  # The mqtt password reuses the mosquitto-meshtastic-password secret.

  sops.secrets."meshtastic-channel-url" = {
    mode = "0400";
  };

  services.meshtasticd = {
    enable = true;
    port = 4403;
    settings = {
      Lora.Module = "sim"; # no physical radio — virtual node over MQTT
      General = {
        MaxNodes = 200;
        MaxMessageQueue = 100;
        # Derive a stable node id from beefcake's NIC MAC.
        MACAddressSource = "eno1";
      };
    };
  };

  # One-time provisioning: set region, import the family channel (name+PSK),
  # enable MQTT uplink/downlink, and point the MQTT module at local Mosquitto.
  # Each `meshtastic --set` reboots the virtual node, so this is guarded by a
  # marker file and only runs once. To re-provision, delete the marker:
  #   /var/lib/meshtasticd/.provisioned
  systemd.services.meshtasticd-provision = {
    description = "Provision meshtasticd virtual node (channel + MQTT), once";
    after = [
      "meshtasticd.service"
      "mosquitto.service"
    ];
    requires = [ "meshtasticd.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.meshtastic ];
    environment = {
      REGION = region;
      MQTT_HOST = mqttHost;
      MQTT_USER = mqttUser;
      CHANNEL_URL_FILE = config.sops.secrets."meshtastic-channel-url".path;
      MQTT_PW_FILE = config.sops.secrets."mosquitto-meshtastic-password".path;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Runs as root so it can read the sops secrets.
    };
    script = ''
      set -euo pipefail
      MARKER=/var/lib/meshtasticd/.provisioned

      # Wait for the meshtasticd client API to come up.
      ready=0
      for _ in $(seq 1 60); do
        if meshtastic --host 127.0.0.1 --info >/dev/null 2>&1; then ready=1; break; fi
        sleep 2
      done
      [ "$ready" = 1 ] || { echo "meshtasticd API not reachable on 127.0.0.1:4403" >&2; exit 1; }

      if [ -f "$MARKER" ]; then
        echo "meshtasticd already provisioned ($MARKER present); skipping."
        exit 0
      fi

      echo "Setting LoRa region to $REGION"
      meshtastic --host 127.0.0.1 --set lora.region "$REGION"

      echo "Importing family channel set from share URL"
      meshtastic --host 127.0.0.1 --seturl "$(cat "$CHANNEL_URL_FILE")"

      echo "Enabling MQTT uplink/downlink on primary channel"
      meshtastic --host 127.0.0.1 --ch-index 0 --ch-set uplink_enabled true --ch-set downlink_enabled true

      echo "Configuring MQTT module -> local Mosquitto"
      meshtastic --host 127.0.0.1 \
        --set mqtt.enabled true \
        --set mqtt.address "$MQTT_HOST" \
        --set mqtt.username "$MQTT_USER" \
        --set mqtt.password "$(cat "$MQTT_PW_FILE")" \
        --set mqtt.encryption_enabled true \
        --set mqtt.json_enabled false \
        --set mqtt.proxy_to_client_enabled false

      touch "$MARKER"
      echo "meshtasticd provisioned."
    '';
  };

  # Client API (4403) stays local — consumed by the mmrelay bridge on this host.
  # Deliberately NOT opened in the firewall.
}
