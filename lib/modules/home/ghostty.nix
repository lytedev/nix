{
  pkgs,
  lib,
  config,
  ...
}:
{
  # options = {
  # };
  config = lib.mkIf config.programs.ghostty.enable {
    home.packages = with pkgs; [
      ghostty
    ];
  };
}
