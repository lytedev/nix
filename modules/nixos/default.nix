# Add your reusable NixOS modules to this directory, on their own file (https://nixos.wiki/wiki/Module).
# These should be stuff you would like to share with others, not your personal configurations.
{
  common = import ./common.nix;
  melee = import ./melee.nix;
  ewwbar = import ./ewwbar.nix;
  desktop-usage = import ./desktop-usage.nix;
  intel = import ./intel.nix;
  pipewire = import ./pipewire.nix;
  pipewire-low-latency = import ./pipewire-low-latency.nix;
  podman = import ./podman.nix;
  postgres = import ./postgres.nix;
  sway = import ./sway.nix;
  hyprland = import ./hyprland.nix;
  user-installed-applications = import ./user-installed-applications.nix;
  wifi = import ./wifi.nix;
  gnome = import ./gnome.nix;
  kde-connect = import ./kde-connect.nix;
}
