{
  base = {
    system = "x86_64-linux";
    modules = [./base.nix];
  };

  dragon = {
    system = "x86_64-linux";
    modules = [
      ./dragon.nix
    ];
  };

  foxtrot = {
    system = "x86_64-linux";
    modules = [./foxtrot.nix];
  };

  thablet = {
    system = "x86_64-linux";
    modules = [./thablet.nix];
  };

  thinker = {
    system = "x86_64-linux";
    modules = [./thinker.nix];
  };

  rascal = {
    system = "x86_64-linux";
    modules = [./rascal.nix];
  };

  router = {
    system = "x86_64-linux";
    modules = [./router.nix];
  };
}
