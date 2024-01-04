{outputs, ...}: {
  home-manager = {
    users.daniel = {
      # TODO: specify an email?
      accounts.email.accounts = {
        primary = {
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

      imports = with outputs.homeManagerModules; [
        common
        senpai
        iex
        cargo
      ];
    };
  };
}
