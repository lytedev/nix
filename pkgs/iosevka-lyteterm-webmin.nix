{
  pkgs,
  parallel,
  python311Packages,
  iosevkaLyteTerm,
  ...
}: let
  BASE_FONTS = "${iosevkaLyteTerm}";
in
  pkgs.stdenvNoCC.mkDerivation {
    inherit BASE_FONTS;
    pname = "iosevkaLyteTermWebMin";
    version = iosevkaLyteTerm.version;
    buildInputs = [parallel] ++ (with python311Packages; [fonttools brotli]);
    PYTHONPATH = pkgs.python3.withPackages (pp: with pp; [brotli]);
    srcs = [
      BASE_FONTS
    ];
    installPhase = ''
      cp "$BASE_FONTS"/woff2/*.woff2 ./
      cp "$BASE_FONTS"/ttf/*.ttf ./
      echo ' !"#$%&'"'"'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~ ‌… ⎜⎡⎣─│┊└├┬╯░▒♯' > ./subset-glyphs.txt
      mkdir -p "$out/share/fonts/woff2"
      mkdir -p "$out/share/fonts/truetype"
      parallel pyftsubset --name-IDs+=0,4,6 --text-file=./subset-glyphs.txt --flavor=woff2 ::: ./*.woff2
      parallel pyftsubset --name-IDs+=0,4,6 --text-file=./subset-glyphs.txt ::: ./*.ttf
      cp ./*.subset.woff2 "$out/share/fonts/woff2"
      cp ./*.subset.ttf "$out/share/fonts/truetype"
      ls -laR
    '';
  }
