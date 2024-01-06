with builtins; (listToAttrs (map (name: {
    name = name;
    value = {
      system = "x86_64-linux";
      modules = [./${name}.nix];
    };
  }) [
    "base"
    "thablet"
    "thinker"
    "foxtrot"
    "beefcake"
    "rascal"
    "musicbox"
    "router"
  ]))
