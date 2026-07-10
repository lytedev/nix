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
    # POST-CUTOVER (2026-07-09): 192.168.0.9 / beefcake-on-the-tailnet is the
    # beefcake-blue GUEST on the thin hypervisor. `deploy .#beefcake` therefore
    # ships the GUEST closure (beefcake-guest = all services + the virtio
    # hardware layer; new paths land in the guest's /nix overlay upper). The
    # bare-metal nixosConfigurations.beefcake remains ONLY as the pre-cutover
    # fallback generation — deploying it to the box would push bare-metal
    # config into the VM. Deploy over the LAN as always (headscale lives in the
    # guest); systemd-touching changes = guest reboot (virsh console = safety
    # net), not live switch.
    beefcake =
      deployer "beefcake" {
        confirmTimeout = 21600;
        activationTimeout = 21600;
      }
      // {
        profiles.system = {
          sshUser = "root";
          path = (deployPkgs "x86_64-linux").deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.beefcake-guest;
        };
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
      # the THIN host should never evaluate the whole flake itself — build on
      # the deployer (dragon, everything cached) and push the small closure
      remoteBuild = false;
      # dragon builds + already holds the whole (tiny) host closure, and the box
      # is LAN-local: stream it directly instead of --substitute-on-destination,
      # which made the host re-resolve every path against nix.h.lyte.dev — a
      # cache now served BY the guest, so it 404s dragon-built host paths and
      # crawls the caddy cascade (cache-story analysis, 2026-07-10).
      fastConnection = true;
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
