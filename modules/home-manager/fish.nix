{
  programs.fish = {
    enable = true;
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

      g = ''
        if test (count $argv) -gt 0
          git $argv
        else
          git status
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
    shellAbbrs = {};
    shellAliases = {
      l = "br";
      ls = "eza --group-directories-first --classify";
      la = "eza -la --group-directories-first --classify";
      lA = "eza -la --all --group-directories-first --classify";
      tree = "eza --tree --level=3";
      lt = "eza -l --sort=modified";
      lat = "eza -la --sort=modified";
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
}
