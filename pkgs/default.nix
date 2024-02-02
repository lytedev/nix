# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
{pkgs, ...}: rec {
  iosevka-lyte-term = pkgs.callPackage ./iosevka-lyte-term.nix {inherit (pkgs) iosevka;};
  iosevka-lyte-term-min = pkgs.callPackage ./iosevka-lyte-term-min.nix {
    inherit pkgs;
    inherit (pkgs) brotli;
    inherit iosevka-lyte-term;
    fonttools = pkgs.python311Packages.fonttools;
  };
  # example = pkgs.callPackage ./example { };
}
