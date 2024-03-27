{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./ewwbar.nix
    ./pipewire.nix
    {
      programs.hyprland = {
        enable = true;
        package = inputs.hyprland.packages.${pkgs.system}.hyprland;
      };
      environment.systemPackages = with pkgs; [hyprpaper xwaylandvideobridge socat];
    }
  ];
}
