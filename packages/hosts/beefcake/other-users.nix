{ pkgs, ... }:
{
  # friends
  users.users.ben = {
    isNormalUser = true;
    # Account retained for file ownership only; no interactive login. Setting the
    # shell to nologin means an SSH session with ben's key is refused/exits
    # immediately instead of dropping into fish.
    shell = pkgs.shadow; # shadow.shellPath = /bin/nologin
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
