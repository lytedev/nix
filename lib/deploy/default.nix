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
    let
      hostSystem = self.nixosConfigurations.${host}.pkgs.stdenv.hostPlatform.system;
    in
    {
      hostname = "${host}.hare-cod.ts.net";
      remoteBuild = true; # should pull from cache
      fastConnection = false;
      interactiveSudo = false;
      profiles.system = {
        sshUser = "root";
        path =
          (deployPkgs hostSystem).deploy-rs.lib.${hostSystem}.activate.nixos
            self.nixosConfigurations.${host};
      };
    }
    // opts;

  # Deployer for aarch64 hosts (like PinePhone)
  aarch64Deployer =
    host: opts:
    {
      hostname = "${host}.hare-cod.ts.net";
      remoteBuild = false; # build locally and push (cross-compile)
      fastConnection = false;
      interactiveSudo = false;
      profiles.system = {
        sshUser = "root";
        path =
          deploy-rs.lib.aarch64-linux.activate.nixos
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
    steamdeck = deployer "steamdeck" { remoteBuild = false; };
    steamdeckoled = deployer "steamdeckoled" { };
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
    pinephone = deployer "pinephone" {
      remoteBuild = false; # build locally, pinephone is slow
    };
  };
}
