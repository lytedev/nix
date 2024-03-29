{pkgs, ...}: {
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  # programs.steam.package = inputs.nixpkgs-stable.legacyPackages.${pkgs.system}.steam;
  programs.steam.remotePlay.openFirewall = true;
  services.udev.packages = with pkgs; [steam];
}
