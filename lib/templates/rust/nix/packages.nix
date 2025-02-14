{ pkgs, ... }:
let
  inherit (builtins) fromTOML readFile;
  pname = "my-package";
  src = ./..;
  main-package = pkgs.rustPlatform.buildRustPackage {
    inherit pname src;
    version = (fromTOML (readFile "${src}/Cargo.toml")).package.version;
    # or for workspaces: version = (fromTOML (readFile "${src}/${pname}/Cargo.toml")).package.version;

    /*
      nativeBuildInputs = with pkgs; [
      pkg-config
      clang
      ];

      buildInputs = with pkgs; [
      ];
    */

    cargoHash = pkgs.lib.fakeHash;
    useFetchCargoVendor = true;
  };
in
{
  ${pname} = main-package;
  default = main-package;
}
