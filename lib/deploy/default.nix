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
      hostname = "${host}.internal.vpn.h.lyte.dev";
      remoteBuild = true; # should pull from cache
      fastConnection = false;
      interactiveSudo = false;
      confirmTimeout = 300;
      activationTimeout = 600;
      profiles.system = {
        sshUser = "root";
        path =
          (deployPkgs hostSystem).deploy-rs.lib.${hostSystem}.activate.nixos
            self.nixosConfigurations.${host};
      };
    }
    // opts;
in
{
  nodes = {
    beefcake = deployer "beefcake" { };
    dragon = deployer "dragon" { };
    # htpc = deployer "htpc" { remoteBuild = false; }; # broken: rtl8812au marked broken upstream
    bigtower = deployer "bigtower" { };
    rascal = deployer "rascal" { };
    mail = deployer "mail" { hostname = "204.168.181.230"; };
    foxtrot = deployer "foxtrot" { };
    thinker = deployer "thinker" { };
    steamdeck = deployer "steamdeck" { remoteBuild = false; };
    steamdeckoled = deployer "steamdeckoled" { };
    flipflop = deployer "flipflop" { };
    babyflip = deployer "babyflip" { };
    flab = deployer "flab" { };
    router = (deployer "router") {
      sshOpts = [
        "-p"
        "2201"
      ];
    };
    # pinephone = deployer "pinephone" { remoteBuild = false; }; # temporarily disabled
  };
}
