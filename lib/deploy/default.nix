{ deploy-rs, self, ... }:
let
  deployPkgs =
    system:
    import self.inputs.nixpkgs {
      inherit system;
      overlays = [
        deploy-rs.overlays.default
        (final: prev: {
          deploy-rs = {
            inherit (prev) deploy-rs;
            lib = deploy-rs.lib;
          };
        })
      ];
    };
  deployer =
    host: opts:
    {
      hostname = "${host}.hare-cod.ts.net";
      remoteBuild = true; # should pull from cache
      fastConnection = false;
      interactiveSudo = false;
      profiles.system = {
        sshUser = "root";
        path =
          (deployPkgs self.nixosConfigurations.${host}.pkgs.system).deploy-rs.lib.x86_64-linux.activate.nixos
            self.nixosConfigurations.${host};
      };
    }
    // opts;
in
{
  nodes = {
    beefcake = deployer "beefcake" { };
    dragon = deployer "dragon" { };
    htpc = deployer "htpc" {
      remoteBuild = false;

    };
    bigtower = deployer "bigtower" { };
    rascal = deployer "rascal" { };
    foxtrot = deployer "foxtrot" { };
    thinker = deployer "thinker" { };
    flipflop = deployer "flipflop" { };
    babyflip = deployer "babyflip" {
      hostname = "nixos";
    };
    router = (deployer "router") {
      sshOpts = [
        "-p"
        "2201"
      ];
    };
  };
}
