{outputs, ...}: {
  imports = with outputs.homeManagerModules; [
    desktop
    pass
  ];
}
