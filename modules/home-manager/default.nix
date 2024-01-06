with builtins;
  listToAttrs (map (name: {
      name = name;
      value = import ./${name}.nix;
    }) [
      "bat"
      "broot"
      "cargo"
      "common"
      "desktop"
      "ewwbar"
      "firefox"
      "fish"
      "git"
      "helix"
      "htop"
      "hyprland"
      "iex"
      "kitty"
      "linux"
      "linux-desktop"
      "macos"
      "mako"
      "melee"
      "nnn"
      "pass"
      "senpai"
      "sway"
      "sway-laptop"
      "swaylock"
      "tmux"
      "waybar"
      "wezterm"
      "zellij"
    ])
