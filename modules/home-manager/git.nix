{lib, ...}: let
  email = lib.mkDefault "daniel@lyte.dev";
in {
  programs.git = {
    enable = true;

    userEmail = email;
    userName = lib.mkDefault "Daniel Flanagan";

    delta = {
      enable = true;
      options = {};
    };

    lfs = {
      enable = true;
    };

    signing = {
      signByDefault = true;
      key = email;
    };

    aliases = {
      a = "add -A";
      ac = "commit -a";
      b = "rev-parse --symbolic-full-name HEAD";
      c = "commit";
      cm = "commit -m";
      cnv = "commit --no-verify";
      co = "checkout";
      d = "diff";
      ds = "diff --staged";
      dt = "difftool";
      f = "fetch";
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

    extraConfig = {
      push = {
        autoSetupRemote = true;
      };

      branch = {
        autoSetupMerge = true;
      };

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
    g = ''
      if test (count $argv) -gt 0
        git $argv
      else
        git status
      end
    '';
  };
}
