{
  imports = [
    ./sway.nix
    ./hyprland.nix
    ./fonts.nix
    ./user-installed-applications.nix
    ./kde-connect.nix
    ./troubleshooting-tools.nix
    ./development-tools.nix
  ];

  hardware = {
    opengl = {
      enable = true;
      driSupport32Bit = true;
      driSupport = true;
    };
  };
}
