{
  inputs,
  system,
  outputs,
  ...
}: {
  home-manager = {
    extraSpecialArgs = {
      inherit inputs outputs system;
      inherit (outputs) colors font;
    };
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

      imports = with outputs.homeManagerModules; [
        common
        gnome
        senpai
        iex
        cargo
      ];
    };
  };
}
