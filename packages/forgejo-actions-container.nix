{
  git,
  findutils,
  coreutils,
  nodejs_24,
  nix,
  gnugrep,
  gawk,
  bash,
  jq,
  dockerTools,
  cacert,
}:
let
  pname = "forgejo-actions-container";
  version = "3";
in
# bootstrap this into the forgejo server with
# $ podman login ${FORGEJO_ENDPOINT:-git.lyte.dev}
# $ podman image load -i (nix build .#forgejo-actions-container --print-out-paths)
# $ podman push git.lyte.dev/lytedev/nix:forgejo-actions-container-v$IMAGE_VERSION-nix-v$NIX_VERSION
dockerTools.buildLayeredImage {
  name = "git.lyte.dev/lytedev/nix";
  tag = "${pname}-v${version}-nix-v${nix.version}";
  config = {
    Cmd = [ "/bin/nix" ];
  };
  contents = [
    nix
    gnugrep
    gawk
    bash
    jq
    findutils
    nodejs_24
    coreutils
    cacert
    git
  ];
}
