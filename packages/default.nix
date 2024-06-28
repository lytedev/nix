{pkgs, ...}: let
  iosevkaLyteTerm = pkgs.callPackage ./iosevkaLyteTerm.nix {};
in rec {
  inherit iosevkaLyteTerm;
  iosevkaLyteTermSubset = pkgs.callPackage ./iosevkaLyteTermSubset.nix {
    inherit iosevkaLyteTerm;
  };
}
