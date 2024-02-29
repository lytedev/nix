{
  base = {
    system = "x86_64-linux";
    modules = [./base.nix];
  };
  beefcake = {
    system = "x86_64-linux";
    modules = [./beefcake.nix];
  };
  dragon = {
    system = "x86_64-linux";
    modules = [./dragon.nix];
  };
  foxtrot = {
    system = "x86_64-linux";
    modules = [./foxtrot.nix];
  };
  musicbox = {
    system = "x86_64-linux";
    modules = [./musicbox.nix];
  };
  rascal = {
    system = "x86_64-linux";
    modules = [./rascal.nix];
  };
  router = {
    system = "x86_64-linux";
    modules = [./router.nix];
  };
  thablet = {
    system = "x86_64-linux";
    modules = [./thablet.nix];
  };
  thinker = {
    system = "x86_64-linux";
    modules = [./thinker.nix];
  };
  # htpifour = {
  #   system = "aarch64-linux";
  #   modules = [./htpifour.nix];
  # };
}
