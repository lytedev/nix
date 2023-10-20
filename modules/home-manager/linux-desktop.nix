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
      name = "Catppuccin-Mocha-Compact-Sapphire-Dark";
      package = pkgs.catppuccin-gtk.override {
        accents = ["sapphire"];
        size = "compact";
        tweaks = ["rimless"];
        variant = "mocha";
      };
    };
  };
}
