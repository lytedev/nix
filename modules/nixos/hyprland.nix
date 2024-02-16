{pkgs, ...}: {
  imports = [
    ./ewwbar.nix
    ./pipewire.nix
  ];
  programs.hyprland.enable = true;
  environment.systemPackages = with pkgs; [hyprpaper];
}
