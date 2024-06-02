# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
{pkgs, ...}: rec {
  # example = pkgs.callPackage ./example { };

  iosevkaLyteTerm = pkgs.callPackage ./iosevka-lyteterm-raw.nix {inherit (pkgs) iosevka;};
  iosevkaLyteTermWebMin = pkgs.callPackage ./iosevka-lyteterm-webmin.nix {
    pkgs = pkgs;
    inherit (pkgs) python311Packages parallel;
    inherit iosevkaLyteTerm;
  };
}
