inputs:
let
  inherit (inputs.self.flakeLib) darwinHost;
in
{
  # TODO: add actual mac hosts here once hostnames are known
  # example-mac = darwinHost ./example-mac.nix { };
  # wife-macbook = darwinHost ./wife-macbook.nix { };
}
