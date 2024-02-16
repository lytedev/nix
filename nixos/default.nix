thisFlake:
with builtins; (listToAttrs (map (name: {
    name = name;
    value = {
      system = "x86_64-linux";
      # specialArgs = thisFlake;
      modules = [./${name}.nix];
    };
  }) [
    "base"
    "htpc"
    "beefcake"
    "dragon"
    "foxtrot"
    "musicbox"
    "rascal"
    "router"
    "thablet"
    "thinker"
  ]))
