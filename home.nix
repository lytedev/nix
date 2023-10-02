inputs:
let
  overlay = system: final: prev: {
    helix = prev.helix // inputs.helix.packages.${system}.helix;
  };
  # TODO: be functional - have a mkHome function?
in
{
  daniel =
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs { inherit system; overlays = [ (overlay system) ]; };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./home/user.nix
        ./home/linux.nix
      ];
    };

  daniel-work =
    let
      system = "aarch64-darwin";
      pkgs = import inputs.nixpkgs { inherit system; overlays = [ (overlay system) ]; };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./home/user.nix
        ./home/work.nix
      ];
    };
}
