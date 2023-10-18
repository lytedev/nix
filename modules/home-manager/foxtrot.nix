{outputs, ...}: {
  imports = with outputs.homeManagerModules; [
    sway
    sway-laptop
  ];

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
