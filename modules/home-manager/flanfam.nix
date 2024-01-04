{...}: {
  home-manager = {
    users.flanfam = {
      imports = [./common.nix];
      home = {
        username = "flanfam";
        homeDirectory = "/home/flanfam";
        stateVersion = "23.11";
      };
    };
  };
}
