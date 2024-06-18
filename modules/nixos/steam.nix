{pkgs, ...}: {
  programs.gamescope.enable = true;

  programs.steam = {
    enable = true;
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

  hardware.steam-hardware.enable = true;
  services.udev.packages = with pkgs; [steam];

  environment.systemPackages = with pkgs; [
    dualsensectl
  ];

  # TODO: remote play ports - should be unnecessary due to
  # programs.steam.remotePlay.openFirewall = true;
  networking.firewall.allowedUDPPortRanges = [
    # UDP 27031, 27036
    {
      from = 27031;
      to = 27036;
    }
  ];
  networking.firewall.allowedTCPPortRanges = [
    # TCP 27036, 27037
    {
      from = 27036;
      to = 27037;
    }
  ];
}
