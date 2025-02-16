{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  config = lib.mkIf config.programs.steam.enable {
    programs.gamescope.enable = true;

    services.pipewire = {
      alsa.support32Bit = true;
    };

    programs.steam = {
      extest.enable = true;
      gamescopeSession.enable = true;

      extraPackages = with pkgs; [
        gamescope
      ];

      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];

      localNetworkGameTransfers.openFirewall = true;
      remotePlay.openFirewall = true;
    };

    hardware =
      (
        if builtins.hasAttr "graphics" options.hardware then
          {
            graphics = {
              enable = true;
              enable32Bit = true;
            };
          }
        else
          {
            opengl = {
              enable = true;
              driSupport32Bit = true;
            };
          }
      )
      // {
        steam-hardware.enable = true;
      };

    services.udev.packages = with pkgs; [ steam ];

    environment.systemPackages = with pkgs; [
      dualsensectl # for interfacing with dualsense controllers programmatically
    ];

    # remote play ports - should be unnecessary due to programs.steam.remotePlay.openFirewall = true;
    /*
      networking.firewall.allowedUDPPortRanges = [ { from = 27031; to = 27036; } ];
      networking.firewall.allowedTCPPortRanges = [ { from = 27036; to = 27037; } ];
    */
  };
}
