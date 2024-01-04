# Add your reusable home-manager modules to this directory, on their own file (https://nixos.wiki/wiki/Module).
# These should be stuff you would like to share with others, not your personal configurations.
{
  # List your module files here
  # my-module = import ./my-module.nix;
  common = import ./common.nix;
  melee = import ./melee.nix;
  linux = import ./linux.nix;
  cargo = import ./cargo.nix;
  macos = import ./macos.nix;
  iex = import ./iex.nix;
  mako = import ./mako.nix;
  git = import ./git.nix;
  helix = import ./helix.nix;
  bat = import ./bat.nix;
  fish = import ./fish.nix;
  kitty = import ./kitty.nix;
  wezterm = import ./wezterm.nix;
  zellij = import ./zellij.nix;
  firefox = import ./firefox.nix;
  broot = import ./broot.nix;
  nnn = import ./nnn.nix;
  waybar = import ./waybar.nix;
  swaylock = import ./swaylock.nix;
  desktop = import ./desktop.nix;
  linux-desktop = import ./linux-desktop.nix;
  sway = import ./sway.nix;
  hyprland = import ./hyprland.nix;
  ewwbar = import ./ewwbar.nix;
  sway-laptop = import ./sway-laptop.nix;
  tmux = import ./tmux.nix;
  htop = import ./htop.nix;
  senpai = import ./senpai.nix;

  flanfam = import ./flanfam.nix;
  flanfamkiosk = import ./flanfamkiosk.nix;

  base = import ./base.nix;
  dragon = import ./dragon.nix;
  thinker = import ./thinker.nix;
  foxtrot = import ./foxtrot.nix;
}
