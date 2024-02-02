{
  pkgs,
  fonttools,
  brotli,
  iosevka-lyteterm,
  ...
}: let
  BASE_FONTS = "${iosevka-lyteterm}/share/fonts/truetype";
in
  pkgs.stdenvNoCC.mkDerivation {
    inherit BASE_FONTS;
    pname = "iosevka-lyteterm-min";
    version = iosevka-lyteterm.version;
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
