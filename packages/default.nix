{ pkgs, ... }:
let
  iosevkaLyteTerm = pkgs.callPackage ./iosevkaLyteTerm.nix { };
in
{
  inherit iosevkaLyteTerm;

  iosevkaLyteTermSubset = pkgs.callPackage ./iosevkaLyteTermSubset.nix {
    inherit iosevkaLyteTerm;
  };
}
