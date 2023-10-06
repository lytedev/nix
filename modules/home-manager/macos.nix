{outputs, ...}: {
  imports = with outputs.homeManagerModules; [
    common
    desktop
  ];

  # TODO: pinentry curses?
  /*
  programs.gnupg.agent = {
    enable = true;
    pinentryFlavor = "gnome3";
    enableSSHSupport = true;
  };
  */
}
