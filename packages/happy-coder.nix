{
  lib,
  buildNpmPackage,
  fetchurl,
  makeBinaryWrapper,
  nodejs,
}:

buildNpmPackage rec {
  pname = "happy-coder";
  version = "0.12.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/happy-coder/-/happy-coder-${version}.tgz";
    hash = "sha256-sVv9H7IYnsA5ccY5PIFS1oix8wmthc/5ERIjbf9/loU=";
  };

  postPatch = ''
    cp ${./happy-coder-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-rhrSXqsjO0z7wxg1nTPTKa0A1Tcz0B0haZqSV1tZLzM=";

  dontNpmBuild = true;

  # Skip the postinstall script that tries to unpack tools
  npmFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeBinaryWrapper ];

  postFixup = ''
    wrapProgram $out/bin/happy \
      --prefix PATH : ${lib.makeBinPath [ nodejs ]}
  '';

  meta = {
    description = "Mobile and Web client for Codex and Claude Code";
    homepage = "https://happy.engineering";
    license = lib.licenses.mit;
    mainProgram = "happy";
  };
}
