{pkgs, ...}: {
  environment.systemPackages = with pkgs; [eww upower jq];
}
