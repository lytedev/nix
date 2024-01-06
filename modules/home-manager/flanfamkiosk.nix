{...}: {
  home-manager = {
    users.flanfamkiosk = {
      imports = [./common.nix];
      home = {
        username = "flanfamkiosk";
        homeDirectory = "/home/flanfamkiosk";
        stateVersion = "23.11";
      };
    };
  };
}
