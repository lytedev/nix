{lib, ...}: let
  email = lib.mkDefault "daniel@lyte.dev";
in {
  programs.git = {
    enable = true;

    userName = lib.mkDefault "Daniel Flanagan";
    userEmail = email;

    delta = {
      enable = true;
      options = {};
    };

    lfs = {
      enable = true;
    };

    # signing = {
    # signByDefault = false;
    # key = ~/.ssh/personal-ed25519;
    # };

    aliases = {
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

    # TODO: https://blog.scottlowe.org/2023/12/15/conditional-git-configuration/
    extraConfig = {
      commit = {
        verbose = true;
        # gpgSign = true;
      };

      tag = {
        # gpgSign = true;
        sort = "version:refname";
      };

      # include.path = local.gitconfig

      gpg.format = "ssh";
      log.date = "local";

      init.defaultBranch = "main";

      merge.conflictstyle = "zdiff3";

      push.autoSetupRemote = true;

      branch.autoSetupMerge = true;

      sendemail = {
        smtpserver = "smtp.mailgun.org";
        smtpuser = email;
        smtrpencryption = "tls";
        smtpserverport = 587;
      };

      url = {
        # TODO: how to have per-machine not-in-git configuration?
        "git@git.hq.bill.com:" = {
          insteadOf = "https://git.hq.bill.com";
        };
      };
    };
  };

  programs.fish.functions = {
    g = {
      wraps = "git";
      body = ''
        if test (count $argv) -gt 0
          git $argv
        else
          git status
        end
      '';
    };
  };
}
