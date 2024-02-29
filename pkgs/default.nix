# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
{
  # pkgs,
  pkgsForIosevka,
  ...
}: rec {
  # example = pkgs.callPackage ./example { };

  iosevka-lyteterm-raw = pkgsForIosevka.callPackage ./iosevka-lyteterm-raw.nix {inherit (pkgsForIosevka) iosevka;};
  iosevka-lyteterm = pkgsForIosevka.callPackage ./iosevka-lyteterm.nix {inherit iosevka-lyteterm-raw;};
  iosevka-lyteterm-webmin = pkgsForIosevka.callPackage ./iosevka-lyteterm-webmin.nix {
    pkgs = pkgsForIosevka;
    inherit (pkgsForIosevka) python311Packages parallel;
    inherit iosevka-lyteterm-raw;
  };
}
