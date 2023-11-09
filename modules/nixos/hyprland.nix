{
  outputs,
  pkgs,
  ...
}: {
  imports = [outputs.nixosModules.ewwbar outputs.nixosModules.pipewire];
  programs.hyprland.enable = true;
  environment.systemPackages = with pkgs; [hyprpaper];
}
