{
  lib,
  stdenv,
  fetchFromGitHub,
  freetype,
  pkg-config,
  dejavu_fonts,
}:
stdenv.mkDerivation {
  pname = "fbkeyboard";
  version = "unstable-2017-08-20";

  src = fetchFromGitHub {
    owner = "julianwi";
    repo = "fbkeyboard";
    rev = "8659f65b08f2b239358384b296cc02a31c073654";
    hash = "sha256-/pGF/3eiYfJP5NhR1uf1auTylF4nS2sB5j0hPdbSQsY=";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ freetype ];

  # Patch the default font path to use dejavu from nix store
  postPatch = ''
    substituteInPlace fbkeyboard.c \
      --replace-fail '"/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"' \
                     '"${dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf"'
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 fbkeyboard $out/bin/fbkeyboard
    runHook postInstall
  '';

  meta = with lib; {
    description = "Simple on-screen keyboard for Linux framebuffer console";
    homepage = "https://github.com/julianwi/fbkeyboard";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
