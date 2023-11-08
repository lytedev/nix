{outputs, ...}: {
  imports = with outputs.homeManagerModules; [
    kitty
    wezterm
  ];
}
