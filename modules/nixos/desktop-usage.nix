{
  imports = [
    ./sway.nix
    # ./hyprland.nix
    # ./plasma.nix
    # ./gnome.nix
    ./fonts.nix
    ./user-installed-applications.nix
    ./kde-connect.nix
    ./troubleshooting-tools.nix
  ];

  hardware = {
    opengl = {
      enable = true;
      driSupport32Bit = true;
      driSupport = true;
    };
  };
}
