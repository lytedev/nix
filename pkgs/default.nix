# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
{pkgs, ...}: rec {
  # example = pkgs.callPackage ./example { };

  iosevka-lyteterm-raw = pkgs.callPackage ./iosevka-lyteterm-raw.nix {inherit (pkgs) iosevka;};
  iosevka-lyteterm = pkgs.callPackage ./iosevka-lyteterm.nix {inherit iosevka-lyteterm-raw;};
  iosevka-lyteterm-webmin = pkgs.callPackage ./iosevka-lyteterm-webmin.nix {
    inherit pkgs;
    inherit (pkgs) python311Packages parallel;
    inherit iosevka-lyteterm-raw;
  };
}
