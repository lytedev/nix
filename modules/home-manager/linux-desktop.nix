{
  pkgs,
  outputs,
  # font,
  ...
}: {
  imports = with outputs.homeManagerModules; [
    desktop
    firefox
  ];

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
