{ pkgs, ... }:
let
  iosevkaLyteTerm = pkgs.callPackage ./iosevkaLyteTerm.nix { };
in
{
  iosevka = pkgs.callPackage ./iosevka.nix { };

  inherit iosevkaLyteTerm;

  iosevkaLyteTermSubset = pkgs.callPackage ./iosevkaLyteTermSubset.nix {
    inherit iosevkaLyteTerm;
  };

  installer = pkgs.callPackage ./installer.nix { };
  ghostty-terminfo = pkgs.callPackage ./ghostty-terminfo.nix { };
}
