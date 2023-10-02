inputs:
{
  daniel =
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs { inherit system; };
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
      pkgs = import inputs.nixpkgs { inherit system; };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./home/user.nix
        ./home/work.nix
      ];
    };
}
