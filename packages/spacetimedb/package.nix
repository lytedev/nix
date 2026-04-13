# Vendored from nixpkgs, updated to v2.1.0
# Uses unstable-packages.rustPlatform for Rust 1.93+ required by SpacetimeDB 2.x
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
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = "clockworklabs";
    repo = "spacetimedb";
    rev = "6981f48b4bc1a71c8dd9bdfe5a2c343f6370243d";
    hash = "sha256-wSJ1co0IpnNva6G9u5oZAjLIw5/bNxOvng2zp/YUFus=";
  };

  cargoHash = "sha256-O1Uug4Xny6AQnybQ978chz+2auY99MUI0o66r44gezI=";

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
