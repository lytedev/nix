# Vendored from nixpkgs, updated to v2.0.1
# Uses unstable-packages.rustPlatform for Rust 1.93+ required by SpacetimeDB 2.0
{
  lib,
  callPackage,
  fetchFromGitHub,
  unstable-packages,
  pkg-config,
  perl,
  openssl,
  versionCheckHook,
  librusty_v8 ? callPackage ./librusty_v8.nix {
    inherit (callPackage ./fetchers.nix { }) fetchLibrustyV8;
  },
}:
unstable-packages.rustPlatform.buildRustPackage (finalAttrs: {
  pname = "spacetimedb";
  version = "2.0.1";

  src = fetchFromGitHub {
    owner = "clockworklabs";
    repo = "spacetimedb";
    rev = "a4d29daec8ed35ce4913a335b7210b9ae3933d00";
    hash = "sha256-CVNL8AQRlOyj4sKwPwA4IjVb7zGCxywbPQP1z0QRA2Q=";
  };

  cargoHash = "sha256-v0QaccrTfIZy7csDYS0Hi+d4jbu0QSK36F1n5c6XadA=";

  nativeBuildInputs = [
    pkg-config
    perl
  ];

  buildInputs = [
    openssl
  ];

  cargoBuildFlags = [ "-p spacetimedb-standalone -p spacetimedb-cli" ];

  preCheck = ''
    # server tests require home dir
    export HOME=$(mktemp -d)
  '';

  checkFlags = [
    # require wasm32-unknown-unknown target
    "--skip=codegen"
    "--skip=publish"
  ];

  doInstallCheck = true;

  env = {
    RUSTY_V8_ARCHIVE = librusty_v8;
    # used by crates/cli/build.rs to set GIT_HASH at compile time
    SPACETIMEDB_NIX_BUILD_GIT_COMMIT = finalAttrs.src.rev;
    # required to make jemalloc_tikv_sys build
    CFLAGS = "-O";
  };

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/bin/spacetime";

  postInstall = ''
    mv $out/bin/spacetimedb-cli $out/bin/spacetime
  '';

  meta = {
    description = "Full-featured relational database system that lets you run your application logic inside the database";
    homepage = "https://github.com/clockworklabs/SpacetimeDB";
    license = lib.licenses.bsl11;
    mainProgram = "spacetime";
  };
})
