{outputs, ...}: {
  imports = with outputs.homeManagerModules; [
    sway
    sway-laptop
    hyprland
  ];
}
