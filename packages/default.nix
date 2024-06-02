{pkgs, ...}: rec {
  iosevkaLyteTerm = pkgs.callPackage ./iosevkaLyteTerm.nix {};
  iosevkaLyteTermSubset = pkgs.callPackage ./iosevkaLyteTermSubset.nix {
    inherit iosevkaLyteTerm;
  };
}
