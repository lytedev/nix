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

  gtk = {
    enable = true;
    # Currently failing: https://github.com/NixOS/nixpkgs/issues/298043
    # Overlay from https://github.com/NixOS/nixpkgs/issues/298043#issuecomment-2015319496
    # Fix on master but not yet in unstable https://github.com/NixOS/nixpkgs/pull/297683
    theme = {
      name = "Catppuccin-Mocha-Compact-Sapphire-Dark";
      package = pkgs.catppuccin-gtk.override {
        accents = ["sapphire"];
        size = "compact";
        tweaks = ["rimless"];
        variant = "mocha";
      };
    };
  };

  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 40; # TODO: this doesn't seem to work -- at least in Sway
    # some icons are also missing (hand2?)
  };
}
