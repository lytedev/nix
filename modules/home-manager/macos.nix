{outputs, ...}: {
  imports = with outputs.homeManagerModules; [
    common
    desktop
  ];
}
