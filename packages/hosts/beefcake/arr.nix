{
  /*
    # https://github.com/NixOS/nixpkgs/blob/04af42f3b31dba0ef742d254456dc4c14eedac86/nixos/modules/services/misc/lidarr.nix#L72
    services.lidarr = {
      enable = true;
      dataDir = "/storage/lidarr";
    };

    services.radarr = {
      enable = true;
      dataDir = "/storage/radarr";
    };

    services.sonarr = {
      enable = true;
      dataDir = "/storage/sonarr";
    };

    services.bazarr = {
      enable = true;
      listenPort = 6767;
    };

    networking.firewall.allowedTCPPorts = [9876 9877];
    networking.firewall.allowedUDPPorts = [9876 9877];
    networking.firewall.allowedUDPPortRanges = [
      {
        from = 27000;
        to = 27100;
      }
    ];
  */
}
