{
  pkgs,
  self,
  ...
}:
let
  version = "1.0.0";
  src = ../.;
  pname = "my-package";
in
{
  ${pname} = pkgs.mixRelease {
    inherit pname version src;
    mixFodDeps = pkgs.fetchMixDeps {
      inherit version src;
      pname = "mix-deps-${pname}";
      sha256 = pkgs.lib.fakeSha256;
    };
    LANG = "C.UTF-8";
    # buildInputs = with pkgs; [];
    # HOME = "$(pwd)";
    # MIX_XDG = "$HOME";
    # RELEASE_COOKIE = "test-cookie";
  };

  default = self.packages.${pkgs.system}.${pname};
}
