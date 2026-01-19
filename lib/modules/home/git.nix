{
  config,
  lib,
  fullName,
  ...
}:
let
  email = config.accounts.email.accounts.primary.address;
in
{
  programs.git = {
    enable = !config.lyte.shell.learn-jujutsu-not-git.enable;

    lfs = {
      enable = true;
    };

    /*
      signing = {
        signByDefault = false;
        key = ~/.ssh/personal-ed25519;
      };
    */

    # TODO: https://blog.scottlowe.org/2023/12/15/conditional-git-configuration/
    settings = {
      user = {
        name = lib.mkDefault fullName;
        email = email;
      };

      alias = {
        a = "add -A";
        ac = "commit -a";
        acm = "commit -a -m";
        c = "commit";
        cm = "commit -m";
        co = "checkout";

        b = "rev-parse --symbolic-full-name HEAD";
        cnv = "commit --no-verify";
        cns = "commit --no-gpg-sign";
        cnvs = "commit --no-verify --no-gpg-sign";
        cnsv = "commit --no-verify --no-gpg-sign";

        d = "diff";
        ds = "diff --staged";
        dt = "difftool";

        f = "fetch";
        fa = "fetch --all";

        l = "log --graph --abbrev-commit --decorate --oneline --all";
        plainlog = " log --pretty=format:'%h %ad%x09%an%x09%s' --date=short --decorate";
        ls = "ls-files";
        mm = "merge master";
        p = "push";
        pf = "push --force-with-lease";
        pl = "pull";
        rim = "rebase -i master";
        s = "status";
      };

      commit = {
        verbose = true;
        # gpgSign = true;
      };

      tag = {
        # gpgSign = true;
        sort = "version:refname";
      };

      # include.path = local.gitconfig

      # gpg.format = "ssh";
      log.date = "local";

      init.defaultBranch = "main";

      merge.conflictstyle = "zdiff3";

      push.autoSetupRemote = true;
      pull.ff = "only";

      branch.autoSetupMerge = true;

      sendemail = {
        smtpserver = "smtp.mailgun.org";
        smtpuser = email;
        smtrpencryption = "tls";
        smtpserverport = 587;
      };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = { };
  };

  programs.fish.functions = {
    jujutsu-git-colocate = ''
      # from https://github.com/jj-vcs/jj/blob/main/docs/git-compatibility.md
      # Ignore the .jj directory in Git
      echo '/*' > .jj/.gitignore
      # Move the Git repo
      mv .jj/repo/store/git .git
      # Tell jj where to find it
      echo -n '../../../.git' > .jj/repo/store/git_target
      # Make the Git repository non-bare and set HEAD
      git config --unset core.bare
      # Convince jj to update .git/HEAD to point to the working-copy commit's parent
      jj new && jj undo
    '';
    g =
      if config.lyte.shell.learn-jujutsu-not-git.enable then
        {
          wraps = "jj";
          body = ''
            if test (count $argv) -gt 0
              jj $argv
            else
              jj status
            end
          '';
        }

      else
        {
          wraps = "git";
          body = ''
            if test (count $argv) -gt 0
              git $argv
            else
              git status
            end
          '';
        };
    lag = {
      wraps = "g";
      body = ''
        lA
        g $argv
      '';
    };
  };
}
