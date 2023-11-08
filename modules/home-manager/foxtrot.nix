{outputs, ...}: {
  imports = with outputs.homeManagerModules; [
    sway
    sway-laptop
    hyprland
  ];

  wayland.windowManager.hyprland = {
    settings = {
      # See https://wiki.hyprland.org/Configuring/Keywords/ for more
      monitor = [
        "eDP-1,2256x1504@60,0x0,1.5"
      ];
    };
  };

  wayland.windowManager.sway = {
    config = {
      output = {
        "BOE 0x0BCA Unknown" = {
          mode = "2256x1504@60Hz";
          scale = "1.25";
        };
      };
    };
  };
}
