{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.fish.enable {
    home = {
      packages = [
        pkgs.gawk # used in prompt
      ];
    };

    programs.fish = {
      # enable = true;
      # I load long scripts from files for a better editing experience
      shellInit = builtins.readFile ./fish/shellInit.fish;
      interactiveShellInit = builtins.readFile ./fish/interactiveShellInit.fish;
      loginShellInit = "";
      functions = {
        # TODO: I think these should be loaded from fish files too for better editor experience?
        d = ''
          # --wraps=cd --description "Quickly jump to NICE_HOME (or given relative or absolute path) and list files."
          if count $argv > /dev/null
            cd $argv
          else
            cd $NICE_HOME
          end
          la
        '';

        c = ''
          if count $argv > /dev/null
            cd $NICE_HOME && d $argv
          else
            d $NICE_HOME
          end
        '';

        ltl = ''
          set d $argv[1] .
          set -l l ""
          for f in $d[1]/*
            if test -z $l; set l $f; continue; end
            if command test $f -nt $l; and test ! -d $f
              set l $f
            end
          end
          echo $l
        '';

        has_command = "command --quiet --search $argv[1]";
      };
      shellAbbrs = { };
      shellAliases = {
        # TODO: an alias that wraps `rm` such that if we run it without git committing first (when in a git repo)
        ls = "eza --group-directories-first --classify";
        l = "ls";
        ll = "ls --long --group";
        la = "ll --all";
        lA = "la --all"; # --all twice to show . and ..
        tree = "ls --tree --level=3";
        lt = "ll --sort=modified";
        lat = "la --sort=modified";
        lc = "lt --sort=accessed";
        lT = "lt --reverse";
        lC = "lc --reverse";
        lD = "la --only-dirs";
        "cd.." = "d ..";
        "cdc" = "d $XDG_CONFIG_HOME";
        "cdn" = "d $NOTES_PATH";
        "cdl" = "d $XDG_DOWNLOAD_DIR";
        "cdg" = "d $XDG_GAMES_DIR";
        ".." = "d ..";
        "..." = "d ../..";
        "...." = "d ../../..";
        "....." = "d ../../../..";
        "......" = "d ../../../../..";
        "......." = "d ../../../../../..";
        "........" = "d ../../../../../../..";
        "........." = "d ../../../../../../../..";
        p = "ping";
        dc = "docker compose";
        pc = "podman-compose";
        k = "kubectl";
        kg = "kubectl get";
        v = "$EDITOR";
        sv = "sudo $EDITOR";
        kssh = "kitty +kitten ssh";
      };
    };
  };
}
