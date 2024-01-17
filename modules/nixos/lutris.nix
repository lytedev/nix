{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      (
        lutris.override {
          extraPkgs = pkgs: [
            # List package dependencies here
            wineWowPackages.waylandFull
          ];
        }
      )
    ];
  };
}
