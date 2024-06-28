{callPackage, ...}: rec {
  iosevkaLyteTerm = callPackage ./iosevkaLyteTerm.nix {};
  iosevkaLyteTermSubset = callPackage ./iosevkaLyteTermSubset.nix {
    inherit iosevkaLyteTerm;
  };
}
