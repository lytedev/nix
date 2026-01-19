{ ... }:
{
  home = {
    username = "daniel";
    homeDirectory = "/home/daniel/.home";
  };

  accounts.email.accounts.primary = {
    primary = true;
    address = "daniel@lyte.dev";
  };

  _module.args.fullName = "Daniel Flanagan";
}
