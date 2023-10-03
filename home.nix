inputs:
let
  mkHome = system: modules:
    let
      overlay = final: prev: {
        helix = prev.helix // inputs.helix.packages.${system}.helix;
      };
      pkgs = import inputs.nixpkgs { inherit system; overlays = [ overlay ]; };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [ ] ++ modules;
    };
in
{
  daniel = mkHome "x86_64-linux" [
    ./home/user.nix
    ./home/linux.nix
  ];

  daniel-work = mkHome "aarch64-darwin" [
    ./home/user.nix
    ./home/work.nix
  ];
}
