{
  rustPlatform,
}:
let
  inherit (builtins) fromTOML readFile;
  pname = "hello_world";
  src = ./.;
  package = rustPlatform.buildRustPackage {
    inherit pname src;
    version = (fromTOML (readFile "${src}/Cargo.toml")).package.version;
    cargoLock = {
      lockFile = ./Cargo.lock;
    };
  };
in
package
