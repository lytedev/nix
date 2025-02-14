{
  pkgs,
  parallel,
  python311Packages,
  iosevkaLyteTerm,
  ...
}:
pkgs.stdenvNoCC.mkDerivation {
  inherit (iosevkaLyteTerm) version;

  pname = "${iosevkaLyteTerm.pname}Subset";
  buildInputs = [parallel] ++ (with python311Packages; [fonttools brotli]);
  PYTHONPATH = pkgs.python3.withPackages (pp: with pp; [brotli]);
  src = iosevkaLyteTerm;

  installPhase = ''
    ls -la "${iosevkaLyteTerm}/share/fonts/woff2"
    cp "${iosevkaLyteTerm}"/share/fonts/woff2/*.woff2 ./
    cp "${iosevkaLyteTerm}"/share/fonts/truetype/*.ttf ./
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
