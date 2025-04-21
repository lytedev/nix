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
  services.caddy.virtualHosts."video.lyte.dev" = {
    extraConfig = ''reverse_proxy :8096'';
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
