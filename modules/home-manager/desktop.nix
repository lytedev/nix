{
  pkgs,
  outputs,
  ...
}: {
  imports = with outputs.homeManagerModules; [
    kitty
    wezterm
  ];

  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 64; # TODO: this doesn't seem to work -- at least in Sway
    # some icons are also missing (hand2?)
  };
}
