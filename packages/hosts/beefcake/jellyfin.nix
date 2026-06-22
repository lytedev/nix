{ lib, pkgs, ... }:
let
  # The public URL Jellyfin should advertise to clients. Without this,
  # /System/Info/Public reports LocalAddress=http://127.0.0.1:8096 (a
  # reverse-proxy quirk) and clients that follow the advertised address fail
  # off-LAN. video.lyte.dev works everywhere via split-horizon DNS (LAN ->
  # 192.168.0.9, public -> WAN), so a single "all=" entry is correct for both.
  publishedUrl = "https://video.lyte.dev";
  netXml = "/var/lib/jellyfin/config/network.xml";

  # The nixpkgs services.jellyfin module doesn't expose network settings, so
  # ensure PublishedServerUriBySubnet declaratively by patching network.xml
  # before each start (idempotent: delete + recreate the element). Jellyfin
  # reads config at startup, so the edit takes effect on the next (re)start.
  # If the file doesn't exist yet (first boot), skip — Jellyfin creates it and
  # the next start applies the setting.
  ensurePublishedUrl = pkgs.writeShellScript "jellyfin-ensure-published-url" ''
    set -eu
    if [ ! -f "${netXml}" ]; then
      echo "jellyfin: ${netXml} absent; skipping published-URL set (applies next start)"
      exit 0
    fi
    ${pkgs.xmlstarlet}/bin/xmlstarlet ed -L \
      -d '/NetworkConfiguration/PublishedServerUriBySubnet' \
      -s '/NetworkConfiguration' -t elem -n PublishedServerUriBySubnet -v "" \
      -s '/NetworkConfiguration/PublishedServerUriBySubnet' -t elem -n string -v 'all=${publishedUrl}' \
      "${netXml}"
    echo "jellyfin: ensured PublishedServerUriBySubnet = all=${publishedUrl}"
  '';
in
{
  systemd.tmpfiles.settings = {
    "10-jellyfin" = {
      "/storage/jellyfin" = {
        "d" = {
          mode = "0770";
          user = "jellyfin";
          group = "wheel";
        };
      };
      "/storage/jellyfin/movies" = {
        "d" = {
          mode = "0770";
          user = "jellyfin";
          group = "wheel";
        };
      };
      "/storage/jellyfin/tv" = {
        "d" = {
          mode = "0770";
          user = "jellyfin";
          group = "wheel";
        };
      };
      "/storage/jellyfin/music" = {
        "d" = {
          mode = "0770";
          user = "jellyfin";
          group = "wheel";
        };
      };
    };
  };
  services.jellyfin = {
    enable = true;
    openFirewall = false;
    # uses port 8096 by default, configurable from admin UI
  };

  # Advertise the public URL (see ensurePublishedUrl above). mkAfter so it
  # appends to any ExecStartPre the module may define rather than replacing it.
  systemd.services.jellyfin.serviceConfig.ExecStartPre = lib.mkAfter [ "${ensurePublishedUrl}" ];

  services.caddy.virtualHosts."video.lyte.dev" = {
    extraConfig = "reverse_proxy :8096";
  };
  /*
    NOTE: this server's xeon chips DO NOT seem to support quicksync or graphics in general
    but I can probably throw in a crappy GPU (or a big, cheap ebay GPU for ML
    stuff, too?) and get good transcoding performance
  */

  # jellyfin hardware encoding
  /*
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vaapiIntel
        vaapiVdpau
        libvdpau-va-gl
        intel-compute-runtime
      ];
    };
    nixpkgs.config.packageOverrides = pkgs: {
      vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
    };
  */
}
