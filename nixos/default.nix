{
  base = {
    system = "x86_64-linux";
    modules = [./base.nix];
  };

  # workstation
  dragon = {
    system = "x86_64-linux";
    modules = [./dragon.nix];
  };

  # primary laptop
  foxtrot = {
    system = "x86_64-linux";
    modules = [./foxtrot.nix];
  };

  # entertainment convertible laptop
  thablet = {
    system = "x86_64-linux";
    modules = [./thablet.nix];
  };

  # thinkpad backup laptop
  thinker = {
    system = "x86_64-linux";
    modules = [./thinker.nix];
  };

  # TODO: stabilize these machines on nixpkgs-stable
  # owned offsite backup
  rascal = {
    system = "x86_64-linux";
    modules = [./rascal.nix];
  };

  # TODO: deploy this to the actual router
  # home gateway
  router = {
    system = "x86_64-linux";
    modules = [./router.nix];
  };

  # htpifour = {
  #   system = "aarch64-linux";
  #   modules = [./htpifour.nix];
  # };
}
