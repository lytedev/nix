{outputs, ...}: {
  imports = with outputs.homeManagerModules; [
    sway
  ];
}
