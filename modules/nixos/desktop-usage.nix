{
  pkgs,
  inputs,
  outputs,
  system,
  ...
}: {
  imports = [
    ./sway.nix
    # ./hyprland.nix
    # ./plasma.nix
    # ./gnome.nix
    ./fonts.nix
    ./user-installed-applications.nix
    ./kde-connect.nix
  ];

  nixpkgs.overlays = [outputs.overlays.modifications];

  hardware = {
    opengl = {
      enable = true;
      driSupport32Bit = true;
      driSupport = true;
    };
  };
}
