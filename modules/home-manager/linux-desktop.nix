{
  outputs,
  # font,
  ...
}: {
  imports = with outputs.homeManagerModules; [
    desktop
    firefox
  ];
}
