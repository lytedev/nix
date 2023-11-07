{
  outputs,
  pkgs,
  ...
}: {
  imports = [outputs.nixosModules.ewwbar];
  programs.hyprland.enable = true;
  environment.systemPackages = with pkgs; [hyprpaper];
}
