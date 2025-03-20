{ pkgs, ... }:
let
  iosevkaLyteTerm = pkgs.callPackage ./iosevkaLyteTerm.nix { };
in
{
  inherit iosevkaLyteTerm;
  iosevka = pkgs.callPackage ./iosevka.nix { };
  iosevkaLyteTermSubset = pkgs.callPackage ./iosevkaLyteTermSubset.nix { };
  # installer = pkgs.callPackage ./installer.nix { };
  ghostty-terminfo = pkgs.callPackage ./ghostty-terminfo.nix { };
  forgejo-actions-container = pkgs.callPackage ./forgejo-actions-container.nix { };
}
