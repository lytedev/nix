{
  pkgs,
  self,
  ...
}: {
  my-package = let
    version = "1.0.0";
    src = ./.;
    pname = "my-package";
  in
    pkgs.beamPackages.mixRelease {
      inherit pname version src;
      mixFodDeps = pkgs.beamPackages.fetchMixDeps {
        inherit version src;
        pname = "mix-deps-${pname}";
        hash = pkgs.lib.fakeSha256;
      };
      # buildInputs = with pkgs; [];
      # HOME = "$(pwd)";
      # MIX_XDG = "$HOME";
    };

  default = self.packages.${pkgs.system}.my-package;
}
