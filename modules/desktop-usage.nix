{ ... }: {
  # TODO: add a DE and include either plasma or gnome as a fallback?
  imports = [
    ./sway.nix
    ./user-installed-applications.nix
  ];

  hardware = {
    opengl = {
      enable = true;
      driSupport32Bit = true;
      driSupport = true;
    };
  };
}

