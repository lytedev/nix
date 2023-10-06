{outputs, ...}: {
  imports = with outputs.homeManagerModules; [
    sway
  ];

  wayland.windowManager.sway = {
    # TODO: firefox initial open on workspace 2
    # TODO: kitty initial open on workspace 1
  };
}
