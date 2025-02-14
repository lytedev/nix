{
  pkgs ? import <nixpkgs> { },
}:
let
  # lock = builtins.fromJSON (builtins.readFile ../../../../../flake.lock);
  # nixpkgsRev = lock.nodes.nixpkgs.locked.rev;
  # pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/${nixpkgsRev}.tar.gz") {};
  pname = "hyprland-workspaces-eww";
  version = "1.0.0";
  src = ./src;
in
pkgs.rustPlatform.buildRustPackage {
  inherit pname version src;
  cargoHash = "sha256-6Wl3cOIxlPJjzEuzNhCBZJXayL8runQfAxPruvzh2Vc=";
  # cargoHash = pkgs.lib.fakeHash;
  checkType = "release";
  postBuild = ''
    # pushd target/*/release
    # ls -la
    # ${pkgs.upx}/bin/upx --best --lzma hyprland-workspaces-eww
    # popd
  '';
}
