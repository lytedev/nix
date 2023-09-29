{ ... }: {
  # TODO: add a DE and include either plasma or gnome as a fallback?
  imports = [
    ./sway.nix
    ./user-installed-applications.nix
  ];
}

