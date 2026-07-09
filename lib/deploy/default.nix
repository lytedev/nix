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
    beefcake = deployer "beefcake" {
      confirmTimeout = 21600;
      activationTimeout = 21600;
    };
    # Phase-3 thin hypervisor. NOT deployed until the cutover
    # (lib/doc/beefcake-thin-host-cutover-runbook.md) — a boot+reboot over the
    # LAN (deploy --boot --hostname <host-mgmt-ip>), like beefcake. The guest
    # keeps deploying as `.#beefcake` (into the active slot). hostname is a
    # placeholder until the host's eno2 mgmt address is assigned at cutover.
    beefcake-host = deployer "beefcake-host" {
      hostname = "beefcake-host.lan";
      confirmTimeout = 21600;
      activationTimeout = 21600;
    };
    dragon = deployer "dragon" { };
    # htpc = deployer "htpc" { remoteBuild = false; }; # broken: rtl8812au marked broken upstream
    bigtower = deployer "bigtower" { hostname = "bigtower.lan"; };
    sanctuary = deployer "sanctuary" { hostname = "sanctuary-av.lan"; };
    rascal = deployer "rascal" { };
    pebble = deployer "pebble" {
      hostname = "204.168.181.230";
      # 2-core box: build the closure on the (beefy, fully-cached) deployer and
      # copy it over, rather than compiling from source on pebble itself.
      remoteBuild = false;
    };
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
