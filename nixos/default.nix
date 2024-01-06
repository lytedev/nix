with builtins; (listToAttrs (map (name: {
    name = name;
    value = {
      system = "x86_64-linux";
      modules = [./${name}.nix];
    };
  }) [
    "base"
    "beefcake"
    "dragon"
    "foxtrot"
    "musicbox"
    "rascal"
    "router"
    "thablet"
    "thinker"
  ]))
