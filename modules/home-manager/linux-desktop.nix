{
  pkgs,
  outputs,
  # font,
  ...
}: {
  imports = with outputs.homeManagerModules; [
    linux
    desktop
    firefox
  ];

  gtk.theme = {
    name = "Catppuccin-Mocha-Compact-Sapphire-Dark";
    package = pkgs.catppuccin-gtk.override {
      accents = ["sapphire"];
      size = "compact";
      tweaks = ["rimless"];
      variant = "mocha";
    };
  };

  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 40; # TODO: this doesn't seem to work -- at least in Sway
    # some icons are also missing (hand2?)
  };
}
