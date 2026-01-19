{ options, ... }:
{
  programs.ssh =
    (
      if builtins.hasAttr "enableDefaultConfig" options.programs.ssh then
        {
          enableDefaultConfig = false;
          matchBlocks = {
            "*" = {
              forwardAgent = false;
              addKeysToAgent = "no";
              compression = false;
              serverAliveInterval = 0;
              serverAliveCountMax = 3;
              hashKnownHosts = false;
              userKnownHostsFile = "~/.ssh/known_hosts";
              controlMaster = "no";
              controlPath = "~/.ssh/master-%r@%n:%p";
              controlPersist = "no";
            };
          };
        }
      else
        {
          extraConfig = ''
            # pass obscure/keys/ssh-key-ed25519 | tail -n 7
          '';
        }
    )
    // {
      enable = true;
      includes = [ "config.d/*" ];
      matchBlocks = {
        "git.lyte.dev" = {
          # hostname = "git.lyte.dev";
          user = "forgejo";
        };
        "github.com" = {
          user = "git";
        };
        "gitlab.com" = {
          user = "git";
        };
        "codeberg.org" = {
          user = "git";
        };
      };
    };
}
