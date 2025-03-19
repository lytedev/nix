{
  nodejs_23,
  nix,
  dockerTools,
}:
let
  pname = "forgejo-actions-container";
in
# bootstrap this into the forgejo server with
# $ podman login ${FORGEJO_ENDPOINT:-git.lyte.dev}
# $ podman image load -i (nix build .#forgejo-actions-container --print-out-paths)
# $ podman image push git.lyte.dev/lytedev/nix:forgejo-actions-container-$NIX_VERSION
dockerTools.buildLayeredImage {
  name = "git.lyte.dev/lytedev/nix";
  tag = "${pname}-${nix.version}";
  config = {
    Cmd = [ "/bin/nix" ];
  };
  contents = [
    nix
    nodejs_23
  ];
}
