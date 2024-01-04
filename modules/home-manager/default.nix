with builtins;
  listToAttrs (map (name: {
      name = name;
      value = import ./${name}.nix;
    }) [
      "common"
      "melee"
      "linux"
      "cargo"
      "macos"
      "iex"
      "mako"
      "git"
      "helix"
      "bat"
      "fish"
      "kitty"
      "wezterm"
      "zellij"
      "firefox"
      "broot"
      "nnn"
      "waybar"
      "swaylock"
      "desktop"
      "linux-desktop"
      "sway"
      "hyprland"
      "ewwbar"
      "sway-laptop"
      "tmux"
      "htop"
      "senpai"
    ])
