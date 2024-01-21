with builtins;
  listToAttrs (map (name: {
      name = name;
      value = import ./${name}.nix;
    }) [
      "common"
      "melee"
      "ewwbar"
      "desktop-usage"
      "fonts"
      "intel"
      "lutris"
      "pipewire"
      "pipewire-low-latency"
      "podman"
      "postgres"
      "sway"
      "hyprland"
      "user-installed-applications"
      "wifi"
      "gnome"
      "kde-connect"
      "printing"
      "avahi"

      "daniel"
      "flanfam"
      "flanfamkiosk"
    ])
