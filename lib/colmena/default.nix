{
  home-manager,
  nixpkgs-unstable,
  self,
  ...
}@inputs:
{
  meta =
    let
      nixpkgsSet =
        nixpkgs:
        (import nixpkgs {
          system = "x86_64-linux";
          overlays = [ self.outputs.flakeLib.forSelfOverlay ];
        });
      nixpkgs = nixpkgsSet nixpkgs-unstable;
      stable = nixpkgsSet nixpkgs;
    in
    {
      inherit nixpkgs;
      nodeNixpkgs = {
        # router = stable;
        beefcake = stable;
      };
      specialArgs = {
        inherit home-manager;
        hardware = inputs.hardware.outputs.nixosModules;
        diskoConfigurations = inputs.self.outputs.diskoConfigurations;
      };
    };

  # TODO: setup builders?
  foxtrot =
    {
      # name,
      # nodes,
      # pkgs,
      ...
    }:
    {
      deployment = {
        # Allow local deployment with `colmena apply-local`
        allowLocalDeployment = true;

        # Disable SSH deployment. This node will be skipped in a
        # normal`colmena apply`.
        targetHost = null;
      };

      imports = [
        inputs.self.outputs.nixosModules.default
        (import ./../../packages/hosts/foxtrot.nix)
      ];

      # boot.isContainer = true;
      # time.timeZone = nodes.host-b.config.time.timeZone;
    };
  beefcake =
    { ... }:
    {
      deployment = {
        buildOnTarget = true;
      };

      imports = [
        inputs.self.outputs.nixosModules.default
        (import ./../../packages/hosts/beefcake.nix)
      ];
    };
}
