{outputs, ...}: {
  imports = with outputs.homeManagerModules; [
    desktop
    pass
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
