# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
{pkgs, ...}: {
  iosevka-lyte-term = pkgs.callPackage ./iosevka-lyte-term.nix {inherit pkgs;};
  # example = pkgs.callPackage ./example { };
}
