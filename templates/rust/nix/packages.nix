{pkgs, ...}: let
  pname = "my-package";
  main-package = pkgs.rustPlatform.buildRustPackage {
    inherit pname;
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
    cargoHash = pkgs.lib.fakeHash;
    useFetchCargoVendor = true;
  };
in {
  ${pname} = main-package;
  default = main-package;
}
