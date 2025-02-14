{
  "deck" =
    let
      system = "x86_64-linux";
      pkgs = unstable.pkgsFor system;
    in
    home-manager-unstable.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = with homeManagerModules; [
        common
        {
          home = {
            homeDirectory = "/home/deck";
            username = "deck";
            stateVersion = "24.11";
          };
        }
        {
          home.packages = with pkgs; [
            ludusavi
            rclone
          ];
        }
        linux
      ];
    };
}
