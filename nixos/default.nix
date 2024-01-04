{
  base = {
    system = "x86_64-linux";
    modules = [./base];
  };

  thablet = {
    system = "x86_64-linux";
    modules = [./thablet];
  };
  thinker = mkNixosSystem "x86_64-linux" [
    ./nixos/thinker
    (danielWithModules [outputs.homeManagerModules.thinker])
  ];
  foxtrot = mkNixosSystem "x86_64-linux" [
    ./nixos/foxtrot
    (danielWithModules [outputs.homeManagerModules.foxtrot])
  ];
  beefcake = mkNixosSystem "x86_64-linux" [
    inputs.api-lyte-dev.nixosModules.x86_64-linux.api-lyte-dev
    ./nixos/beefcake
    (danielWithModules [outputs.homeManagerModules.linux])
  ];
  rascal = mkNixosSystem "x86_64-linux" [
    ./nixos/rascal
    (danielWithModules [outputs.homeManagerModules.linux])
  ];
  musicbox = mkNixosSystem "x86_64-linux" [
    ./nixos/musicbox
    (danielWithModules [outputs.homeManagerModules.sway])
  ];
  router = mkNixosSystem "x86_64-linux" [
    ./nixos/router
    (danielWithModules [outputs.homeManagerModules.common])
  ];
}
