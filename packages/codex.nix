{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  nodejs,
}:

stdenv.mkDerivation rec {
  pname = "codex";
  version = "0.85.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}.tgz";
    hash = "sha256-S+UIuUJL0HxP2vQ0wTdkdI8TeQb1iFs2SkauEBkM2P4=";
  };

  nativeBuildInputs = [ makeWrapper ];

  unpackPhase = ''
    runHook preUnpack
    mkdir source
    tar -xzf $src -C source
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/codex $out/bin
    cp -r source/package/* $out/lib/codex/
    chmod +x $out/lib/codex/bin/codex.js
    makeWrapper ${lib.getExe nodejs} $out/bin/codex \
      --add-flags $out/lib/codex/bin/codex.js
    runHook postInstall
  '';

  meta = {
    description = "Codex CLI is a coding agent from OpenAI that runs locally on your computer";
    homepage = "https://github.com/openai/codex#readme";
    license = lib.licenses.asl20;
    mainProgram = "codex";
  };
}
