{pkgs, ...}: rec {
  lyrs = pkgs.rustPlatform.buildRustPackage {
    pname = "lyrs";
    version = "0.1.0";

    /*
    nativeBuildInputs = with pkgs; [
    pkg-config
    clang
    ];

    buildInputs = with pkgs; [
    ];
    */

    src = ./..;
    hash = pkgs.lib.fakeHash;
    cargoHash = "sha256-XHCXOlG4sdr1A3lqIK/7bB3soms1jxMIdfsFABmHVog=";
  };

  pwatch = pkgs.writeShellScriptBin "pwatch" ''
    dir="$(dirname "$(cargo locate-project --workspace --message-format plain)")"
    pushd "$dir"

    additional_watchexec_args=""
    if [[ -f apps/$pkg/build.rs ]]; then
      additional_watchexec_args="--watch apps/$pkg/build.rs"
    fi

    pkg="$1"; shift
    cargo_subcmd="$1"; shift
    cargo_subcmd_args="$@"; shift

    argfile="apps/$pkg/.watchexec.argfile"
    argfile_args=""

    if [[ -f $argfile ]]; then
      argfile_args="@$argfile"
    fi
    watchexec $argfile_args --stop-timeout 0s --restart \
      --watch Cargo.toml \
      --watch libs \
      --watch apps/$pkg/src/ \
      --watch apps/$pkg/Cargo.toml \
      $additional_watchexec_args \
      cargo "$cargo_subcmd" --package "$pkg" "$cargo_subcmd_args"

    popd
  '';

  default = lyrs;
}
