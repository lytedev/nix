{
  lib,
  buildNpmPackage,
  fetchurl,
}:

buildNpmPackage rec {
  pname = "claude-code";
  version = "2.0.72";

  src = fetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    hash = "sha256-MeDnwe98890zSqRvqqePzrzYirKrLNmE2P2wL9lxaK0=";
  };

  postPatch = ''
    cp ${./claude-code-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-fUxOINLRXoXYyQzxmo2vtolzMr7mBIAct9hwNOAhNdg=";

  dontNpmBuild = true;

  env.AUTHORIZED = "1";

  postInstall = ''
    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --unset DEV
  '';

  meta = {
    description = "Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster";
    homepage = "https://github.com/anthropics/claude-code";
    downloadPage = "https://www.npmjs.com/package/@anthropic-ai/claude-code";
    license = lib.licenses.unfree;
    mainProgram = "claude";
  };
}
