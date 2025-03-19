{
  pkgs,
  ghostty,
  ...
}:
pkgs.stdenvNoCC.mkDerivation {
  inherit (ghostty) version;

  pname = "${ghostty.pname}-terminfo";
  buildInputs = [ ghostty ];
  src = ghostty;

  installPhase = ''
    mkdir -p "$out/share/"
    cp -r "$src/share/terminfo" "$out/share/"
  '';
}
