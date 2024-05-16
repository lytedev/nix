with builtins;
  listToAttrs (map (name: {
      name = name;
      value = import ./${name}.nix;
    }) [
      "avahi"
      "common"
      "desktop-usage"
      "ewwbar"
      "fonts"
      "gnome"
      "hyprland"
      "intel"
      "kde-connect"
      "kde-plasma"
      "lutris"
      "melee"
      "pipewire"
      "pipewire-low-latency"
      "music-production"
      "podman"
      "postgres"
      "printing"
      "steam"
      "sway"
      "user-installed-applications"
      "wifi"

      "daniel"
      "flanfam"
      "flanfamkiosk"
    ])
