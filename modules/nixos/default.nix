# Add your reusable NixOS modules to this directory, on their own file (https://nixos.wiki/wiki/Module).
# These should be stuff you would like to share with others, not your personal configurations.
{
  common = import ./common.nix;
  melee = import ./melee.nix;
  desktop-usage = import ./desktop-usage.nix;
  intel = import ./intel.nix;
  pipewire = import ./pipewire.nix;
  podman = import ./podman.nix;
  postgres = import ./postgres.nix;
  sway = import ./sway.nix;
  user-installed-applications = import ./user-installed-applications.nix;
  wifi = import ./wifi.nix;
}
