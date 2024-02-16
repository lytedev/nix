{
  home-manager = {
    users.daniel = {
      accounts.email.accounts = {
        primary = {
          primary = true;
          address = "daniel@lyte.dev";
        };
        legacy = {
          address = "wraithx2@gmail.com";
        };
        io = {
          # TODO: finalize deprecation
          address = "daniel@lytedev.io";
        };
        # TODO: may need to use a sops secret? put in another module?
        # work = {
        #   address = "REDACTED";
        # };
      };

      home = {
        username = "daniel";
        homeDirectory = "/home/daniel/.home";
      };

      imports = [
        ./common.nix
        ./gnome.nix
        ./senpai.nix
        ./iex.nix
        ./cargo.nix
      ];
    };
  };
}
