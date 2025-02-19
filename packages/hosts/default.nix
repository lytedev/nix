inputs:
let
  inherit (inputs.self.flakeLib) host stableHost;
in
{
  beefcake = stableHost ./beefcake.nix { };
  dragon = host ./dragon.nix { };
  foxtrot = host ./foxtrot.nix { };
  thinker = host ./thinker.nix { };
  htpc = stableHost ./htpc.nix { };
  router = stableHost ./router.nix { };
  bigtower = stableHost ./bigtower.nix { };
  # arm-dragon = host ./dragon.nix { system = "aarch64-linux"; };
}
