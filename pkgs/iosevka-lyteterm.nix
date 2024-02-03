{
  pkgs,
  iosevka-lyteterm-raw,
  ...
}: let
  BASE_FONTS = "${iosevka-lyteterm-raw}/iosevka-lyteterm/ttf";
in
  pkgs.stdenvNoCC.mkDerivation {
    inherit BASE_FONTS;
    pname = "iosevka-lyteterm-ttf";
    version = iosevka-lyteterm-raw.version;
    srcs = [
      BASE_FONTS
    ];
    installPhase = ''
      mkdir -p "$out/share/fonts/truetype"
      for f in "$BASE_FONTS"/*.ttf; do
        cp "$f" "$out/share/fonts/truetype"
      done
    '';
  }
