{pkgs, ...}: {
  # fonts.packages if unstable?
  fonts.packages = with pkgs; [
    (nerdfonts.override {fonts = ["NerdFontsSymbolsOnly"];})
    pkgs.iosevka-lyte-term
  ];
}
