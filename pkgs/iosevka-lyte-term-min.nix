{
  pkgs,
  fonttools,
  brotli,
  iosevka-lyte-term,
  ...
}: let
  BASE_FONTS = "${iosevka-lyte-term}/share/fonts/truetype";
in
  pkgs.stdenvNoCC.mkDerivation {
    inherit BASE_FONTS;
    pname = "iosevka-lyte-term-min";
    version = iosevka-lyte-term.version;
    # do I need to include makesubset.bash and subset-glyphs.txt?
    buildInputs = [fonttools brotli];
    srcs = [
      BASE_FONTS
      ./makesubset.bash
    ];
    installPhase = ''
      mkdir -p "$out/share/fonts/truetype"
      for f in "$BASE_FONTS"/dist/iosevkalyteweb/woff2/*.woff2; do
      	if [[ $f == *".subset.woff2"* ]]; then
      		pyftsubset "$f" --name-IDs+=0,4,6 --text-file=./subset-glyphs.txt --flavor=woff2 &
      	fi
      done
      wait
    '';
  }
