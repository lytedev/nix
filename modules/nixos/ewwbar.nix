{pkgs, ...}: {
  environment.systemPackages = with pkgs; [eww-wayland];
}
