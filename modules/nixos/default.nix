with builtins;
  listToAttrs (map (name: {
      name = name;
      value = import ./${name}.nix;
    }) [
      "common"
      "melee"
      "ewwbar"
      "desktop-usage"
      "intel"
      "pipewire"
      "pipewire"
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
