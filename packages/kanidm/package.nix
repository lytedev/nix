# Vendored from nixpkgs nixos-unstable (commit 0182a361), pinned to kanidm
# trunk for SCIM array-URL fix (kanidm#4271, merged after v1.9.2). Revert to
# a tagged version once a release past v1.9.2 ships that fix.
{
  stdenv,
  lib,
  formats,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  pkg-config,
  udev,
  openssl,
  sqlite,
  pam,
  bashInteractive,
  rust-jemalloc-sys,
}:

let
  arch = if stdenv.hostPlatform.isx86_64 then "x86_64" else "generic";
  trunkRev = "c070a41192e9f82f0b58985f02e6055980ba7929";
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "kanidm";
  version = "1.10.0-dev-${builtins.substring 0 8 trunkRev}";

  cargoDepsName = "kanidm";

  src = fetchFromGitHub {
    owner = "kanidm";
    repo = "kanidm";
    rev = trunkRev;
    hash = "sha256-qLMzo2DWQILZ5VLqNuVQA6Dwmy4oFcZ7Quf5j8mDE6E=";
  };

  cargoHash = "sha256-91IQPo3s4pbM+yotN0DFZVbCCzs6Pc4jZwcsetGBMf4=";

  env.KANIDM_BUILD_PROFILE = "release_nixpkgs_${arch}";

  postPatch =
    let
      format = (formats.toml { }).generate "${finalAttrs.env.KANIDM_BUILD_PROFILE}.toml";
      profile = {
        cpu_flags = if stdenv.hostPlatform.isx86_64 then "x86_64_legacy" else "none";
        client_config_path = "/etc/kanidm/config";
        resolver_config_path = "/etc/kanidm/unixd";
        resolver_unix_shell_path = "${lib.getBin bashInteractive}/bin/bash";
        server_admin_bind_path = "/run/kanidmd/sock";
        server_config_path = "/etc/kanidm/server.toml";
        server_ui_pkg_path = "@htmx_ui_pkg_path@";
        resolver_service_account_token_path = "/etc/kanidm/token";
        server_migration_path = "/etc/kanidm/migrations.d";
      };
    in
    ''
      cp ${format profile} libs/profiles/${finalAttrs.env.KANIDM_BUILD_PROFILE}.toml
      substituteInPlace libs/profiles/${finalAttrs.env.KANIDM_BUILD_PROFILE}.toml --replace-fail '@htmx_ui_pkg_path@' "$out/ui/hpkg"
      substituteInPlace Cargo.toml \
        --replace-fail 'rust-version = "1.93"' 'rust-version = "1.91"'
    '';

  nativeBuildInputs = [
    pkg-config
    installShellFiles
  ];

  buildInputs = [
    openssl
    sqlite
    pam
    rust-jemalloc-sys
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    udev
  ];

  # The UI needs to be in place before the tests are run.
  postBuild = ''
    mkdir -p $out/ui
    cp -r server/core/static $out/ui/hpkg
  '';

  env.RUSTFLAGS = "--cap-lints warn";

  cargoTestFlags = [
    "--config"
    ''profile.release.lto="off"''
  ];

  # Skip tests: trunk adds tests that require network/CA/SMTP and fail in
  # the nix sandbox (kanidm-mail-sender, kanidm_client, kanidm_tools). We
  # pin trunk temporarily for the SCIM URL fix; upstream CI covers these.
  doCheck = false;

  preFixup = ''
    installShellCompletion \
      --bash $releaseDir/build/completions/*.bash \
      --zsh $releaseDir/build/completions/_* \
      --fish $releaseDir/build/completions/*.fish
  ''
  + lib.optionalString (!stdenv.hostPlatform.isDarwin) ''
    # PAM and NSS need fix library names
    mv $out/lib/libnss_kanidm.so $out/lib/libnss_kanidm.so.2
    mv $out/lib/libpam_kanidm.so $out/lib/pam_kanidm.so
  '';

  passthru = {
    eolMessage = "";
  };

  # can take over 4 hours on 2 cores and needs 16GB+ RAM
  requiredSystemFeatures = [ "big-parallel" ];

  meta = {
    changelog = "https://github.com/kanidm/kanidm/releases/tag/v${finalAttrs.version}";
    description = "Simple, secure and fast identity management platform";
    homepage = "https://github.com/kanidm/kanidm";
    license = lib.licenses.mpl20;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "kanidmd";
  };
})
