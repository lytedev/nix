{ pkgs, ... }:
{
  # friends
  users.users.ben = {
    isNormalUser = true;
    packages = [ pkgs.vim ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKUfLZ+IX85p9355Po2zP1H2tAxiE0rE6IYb8Sf+eF9T"
    ];
  };

  users.users.alan = {
    isNormalUser = true;
    packages = [ pkgs.vim ];
    # openssh.authorizedKeys.keys = [];
  };
}
