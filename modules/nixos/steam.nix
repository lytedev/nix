{pkgs, ...}: {
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  # programs.steam.package = inputs.nixpkgs-stable.legacyPackages.${pkgs.system}.steam;
  programs.steam.remotePlay.openFirewall = true;
  services.udev.packages = with pkgs; [steam];

  # remote play ports
  networking.firewall.allowedUDPPortRanges = [
    {
      from = 27031;
      to = 27036;
    }
  ];
  networking.firewall.allowedTCPPortRanges = [
    {
      from = 27036;
      to = 27037;
    }
  ];
  # UDP 27031, 27036
  # TCP 27036, 27037
}
