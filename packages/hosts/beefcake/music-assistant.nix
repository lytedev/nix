# Music Assistant — the audio control plane, moved off bigtower to beefcake so
# it's backed up (restic), TLS-routed (music-assistant.h.lyte.dev via Caddy —
# which makes the Spotify OAuth callback actually work), and on the always-on
# server. Host networking is required for Cast/AirPlay mDNS discovery. The
# /var/lib/music-assistant data dir carries over the admin user, the HA token,
# the provider logins, and the synced library from bigtower.
{ ... }:
{
  systemd.tmpfiles.settings."10-music-assistant" = {
    "/var/lib/music-assistant"."d" = {
      mode = "0750";
      user = "root";
      group = "root";
    };
  };

  virtualisation.oci-containers.containers.music-assistant = {
    image = "ghcr.io/music-assistant/server:2.8.7";
    autoStart = true;
    extraOptions = [ "--network=host" ];
    volumes = [ "/var/lib/music-assistant:/data" ];
  };

  # :8095 (admin/API) is fronted by Caddy with TLS and is NOT opened directly on
  # the firewall (only Caddy reaches it over loopback). :8097 (audio stream) +
  # :3483 (SlimProto) stay LAN-open so Cast players and the steamdeck's
  # squeezelite can pull/connect.
  networking.firewall.allowedTCPPorts = [
    8097
    3483
  ];

  services.caddy.virtualHosts."music-assistant.h.lyte.dev".extraConfig = ''
    reverse_proxy :8095
  '';

  # Back up the data dir (admin user, HA token, provider logins, library).
  services.restic.commonPaths = [ "/var/lib/music-assistant" ];
}
