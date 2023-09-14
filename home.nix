inputs:
{
  # TODO: per arch?
  daniel = let
    system = "x86_64-linux";
    pkgs = inputs.nixpkgs.legacyPackages.${system};
  in inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      (import
        ./home/daniel.nix
        ./home/linux.nix

        pkgs)
    ];
  };

  daniel-work = let
    system = "aarch64-darwin";
    pkgs = inputs.nixpkgs.legacyPackages.${system};
  in inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      (import
        ./home/daniel.nix

        pkgs)
    ];
  };
}
