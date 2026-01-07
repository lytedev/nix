# Pre-built Iosevka Lyte font downloaded from files.lyte.dev
# To update: build the font with `nix build github:lytedev/iosevka-lyte`, then upload to files.lyte.dev
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "33.2.2";
in
stdenvNoCC.mkDerivation {
  pname = "iosevka-lyte-term-bin";
  inherit version;

  src = fetchurl {
    url = "https://files.lyte.dev/projects/iosevka-lyte/IosevkaLyteTerm-${version}-ttf.tar.gz";
    hash = "sha256-NDvbuvMaFx5tGP5w/Srq2VhweXAHQ8lBJCPFPhrwClk=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm644 -t $out/share/fonts/truetype/ *.ttf

    runHook postInstall
  '';

  meta = with lib; {
    description = "Iosevka Lyte Term - pre-built binary distribution";
    homepage = "https://github.com/lytedev/iosevka-lyte";
    license = licenses.ofl;
    platforms = platforms.all;
  };
}
