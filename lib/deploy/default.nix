{ deploy-rs, self, ... }:
let
  deployer =
    host: opts:
    {
      hostname = "${host}.hare-cod.ts.net";
      remoteBuild = true; # should pull from cache # TODO: verify this
      fastConnection = true;
      interactiveSudo = true;
      profiles.system = {
        user = "root";
        path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.${host};
      };
    }
    // opts;
in
{
  nodes = {
    beefcake = deployer "beefcake" { };
    dragon = deployer "dragon" { };
    htpc = deployer "htpc" { };
    bigtower = deployer "bigtower" { };
    rascal = deployer "rascal" { };
    router = (deployer "router") {
      sshOpts = [
        "-p"
        "2201"
      ];
    };
  };
}
