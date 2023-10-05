{
  outputs,
  pkgs,
  ...
}: {
  imports = with outputs.homeManagerModules; [
    kitty
    firefox
  ];

  programs.foot = {
    enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "Catppuccin-Mocha-Compact-Sapphire-dark";
      package = pkgs.catppuccin-gtk.override {
        accents = ["sapphire"];
        size = "compact";
        tweaks = ["rimless" "black"];
        variant = "mocha";
      };
    };
  };
}
