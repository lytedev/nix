# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
{pkgs, ...}: rec {
  iosevka-lyteterm = pkgs.callPackage ./iosevka-lyteterm.nix {inherit (pkgs) iosevka;};
  iosevka-lyteterm-min = pkgs.callPackage ./iosevka-lyteterm-min.nix {
    inherit pkgs;
    inherit (pkgs) brotli;
    inherit iosevka-lyteterm;
    fonttools = pkgs.python311Packages.fonttools;
  };
  # example = pkgs.callPackage ./example { };
}
