{pkgs, ...}: rec {
  my-package = pkgs.rustPlatform.buildRustPackage {
    pname = "my-binary";
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
  };

  default = my-package;
}
