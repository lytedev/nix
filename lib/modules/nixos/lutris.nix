{ pkgs, ... }:
{
  environment = {
    systemPackages = with pkgs; [
      wineWowPackages.waylandFull
      lutris
      winetricks
    ];
  };
}
