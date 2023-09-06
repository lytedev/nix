{ pkgs, lib, ... }: {
  # TODO: email access?
  # accounts.email.accounts = {
  #   google = {
  #     address = "wraithx2@gmail.com";
  #   };
  # };

  home.username = "daniel";
  home.homeDirectory = lib.mkDefault "/home/daniel/.home";
  home.stateVersion = "23.05";

  home.packages = [
    pkgs.rtx
    # I use this for managing the following programs' versions instead of nix:
    # kubectl, aws

    # TODO: os-specific scripts? macOS versus Linux (arch or nixos? do I need to distinguish at that point?)
    (pkgs.buildEnv { name = "my-scripts"; paths = [ ./scripts ]; })
  ];

  programs.password-store = {
    enable = true;
    package = (pkgs.pass.withExtensions (exts: [ exts.pass-otp ]));
  };

  programs.zellij = {
    # TODO: enable after port config
    enable = false;
    enableFishIntegration = true;
    settings = {
      # TODO: port config
    };
  };

  programs.broot = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      modal = true;
      skin = {
        # this is a crappy copy of broot's catppuccin mocha theme
        input = "rgb(205, 214, 244) none";
        selected_line = "none rgb(88, 91, 112)";
        default = "rgb(205, 214, 244) none";
        tree = "rgb(108, 112, 134) none";
        parent = "rgb(116, 199, 236) none";
        file = "none none";

        perm__ = "rgb(186, 194, 222) none";
        perm_r = "rgb(250, 179, 135) none";
        perm_w = "rgb(235, 160, 172) none";
        perm_x = "rgb(166, 227, 161) none";
        owner = "rgb(148, 226, 213) none";
        group = "rgb(137, 220, 235) none";

        dates = "rgb(186, 194, 222) none";

        directory = "rgb(180, 190, 254) none Bold";
        exe = "rgb(166, 227, 161) none";
        link = "rgb(249, 226, 175) none";
        pruning = "rgb(166, 173, 200) none Italic";

        preview_title = "rgb(205, 214, 244) rgb(24, 24, 37)";
        preview = "rgb(205, 214, 244) rgb(24, 24, 37)";
        preview_line_number = "rgb(108, 112, 134) none";

        char_match = "rgb(249, 226, 175) rgb(69, 71, 90) Bold Italic";
        content_match = "rgb(249, 226, 175) rgb(69, 71, 90) Bold Italic";
        preview_match = "rgb(249, 226, 175) rgb(69, 71, 90) Bold Italic";

        count = "rgb(249, 226, 175) none";
        sparse = "rgb(243, 139, 168) none";
        content_extract = "rgb(243, 139, 168) none Italic";

        git_branch = "rgb(250, 179, 135) none";
        git_insertions = "rgb(250, 179, 135) none";
        git_deletions = "rgb(250, 179, 135) none";
        git_status_current = "rgb(250, 179, 135) none";
        git_status_modified = "rgb(250, 179, 135) none";
        git_status_new = "rgb(250, 179, 135) none Bold";
        git_status_ignored = "rgb(250, 179, 135) none";
        git_status_conflicted = "rgb(250, 179, 135) none";
        git_status_other = "rgb(250, 179, 135) none";
        staging_area_title = "rgb(250, 179, 135) none";

        flag_label = "rgb(243, 139, 168) none";
        flag_value = "rgb(243, 139, 168) none Bold";

        status_normal = "none rgb(24, 24, 37)";
        status_italic = "rgb(243, 139, 168) rgb(24, 24, 37) Italic";
        status_bold = "rgb(235, 160, 172) rgb(24, 24, 37) Bold";
        status_ellipsis = "rgb(235, 160, 172) rgb(24, 24, 37) Bold";
        status_error = "rgb(205, 214, 244) rgb(243, 139, 168)";
        status_job = "rgb(235, 160, 172) rgb(40, 38, 37)";
        status_code = "rgb(235, 160, 172) rgb(24, 24, 37) Italic";
        mode_command_mark = "rgb(235, 160, 172) rgb(24, 24, 37) Bold";

        help_paragraph = "rgb(205, 214, 244) none";
        help_headers = "rgb(243, 139, 168) none Bold";
        help_bold = "rgb(250, 179, 135) none Bold";
        help_italic = "rgb(249, 226, 175) none Italic";
        help_code = "rgb(166, 227, 161) rgb(49, 50, 68)";
        help_table_border = "rgb(108, 112, 134) none";

        hex_null = "rgb(205, 214, 244) none";
        hex_ascii_graphic = "rgb(250, 179, 135) none";
        hex_ascii_whitespace = "rgb(166, 227, 161) none";
        hex_ascii_other = "rgb(148, 226, 213) none";
        hex_non_ascii = "rgb(243, 139, 168) none";

        file_error = "rgb(251, 73, 52) none";

        purpose_normal = "none none";
        purpose_italic = "rgb(177, 98, 134) none Italic";
        purpose_bold = "rgb(177, 98, 134) none Bold";
        purpose_ellipsis = "none none";

        scrollbar_track = "rgb(49, 50, 68) none";
        scrollbar_thumb = "rgb(88, 91, 112) none";

        good_to_bad_0 = "rgb(166, 227, 161) none";
        good_to_bad_1 = "rgb(148, 226, 213) none";
        good_to_bad_2 = "rgb(137, 220, 235) none";
        good_to_bad_3 = "rgb(116, 199, 236) none";
        good_to_bad_4 = "rgb(137, 180, 250) none";
        good_to_bad_5 = "rgb(180, 190, 254) none";
        good_to_bad_6 = "rgb(203, 166, 247) none";
        good_to_bad_7 = "rgb(250, 179, 135) none";
        good_to_bad_8 = "rgb(235, 160, 172) none";
        good_to_bad_9 = "rgb(243, 139, 168) none";
      };

      verbs = [
        { invocation = "edit"; shortcut = "e"; execution = "$EDITOR {file}"; }
      ];
    };
  };

  programs.home-manager.enable = true;

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  programs.fish = {
    enable = true;
    # I load long scripts from files for a better editing experience
    shellInit = builtins.readFile ./fish/shellInit.fish;
    interactiveShellInit = builtins.readFile ./fish/interactiveShellInit.fish;
    loginShellInit = "";
    functions = {
      # I think these should be loaded from fish files too for better editor experience
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
        if count $argv > /dev/null
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
    shellAbbrs = { };
    shellAliases = {
      l = "br";
      ls = "exa --group-directories-first --classify";
      la = "exa -la --group-directories-first --classify";
      lA = "exa -la --all --group-directories-first --classify";
      tree = "exa --tree --level=3";
      lt = "exa -l --sort=modified";
      lat = "exa -la --sort=modified";
      lc = "lt --sort=accessed";
      lT = "lt --reverse";
      lC = "lc --reverse";
      lD = "la --only-dirs";
      "cd.." = "d ..";
      "cdd" = "d $DOTFILES_PATH";
      "cde" = "d $XDG_CONFIG_HOME/lytedev-env";
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
      cat = "bat";
      dc = "docker compose";
      k = "kubectl";
      kg = "kubectl get";
      v = "$EDITOR";
      sv = "sudo $EDITOR";
      kssh = "kitty +kitten ssh";
    };
  };

  programs.exa.enable = true;

  programs.skim = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

  home.pointerCursor = {
    name = "Catppuccin-Mocha-Sapphire-Cursors";
    package = pkgs.catppuccin-cursors.mochaSapphire;
    size = 64; # TODO: this doesn't seem to work -- at least in Sway
  };

  programs.firefox = {
    # TODO: enable dark theme by default
    enable = true;

    package = (pkgs.firefox.override { extraNativeMessagingHosts = [ pkgs.passff-host ]; });

    # extensions = with pkgs.nur.repos.rycee.firefox-addons; [
    #   ublock-origin
    # ]; # TODO: would be nice to have _all_ my firefox stuff managed here instead of Firefox Sync maybe?

    profiles = {
      daniel = {
        id = 0;
        settings = {
          "general.smoothScroll" = true;
        };

        extraConfig = ''
          user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
          // user_pref("full-screen-api.ignore-widgets", true);
          user_pref("media.ffmpeg.vaapi.enabled", true);
          user_pref("media.rdd-vpx.enabled", true);
        '';

        userChrome = ''
          #webrtcIndicator {
          	display: none;
          }

          #main-window[tabsintitlebar="true"]:not([extradragspace="true"]) #TabsToolbar>.toolbar-items {
          	opacity: 0;
          	pointer-events: none;
          }

          #main-window:not([tabsintitlebar="true"]) #TabsToolbar {
          	visibility: collapse !important;
          }
        '';

        # userContent = ''
        # '';
      };

    };
  };

  # wayland.windowManager.sway = {
  #   enable = true;
  # }; # TODO: would be nice to have my sway config declared here instead of symlinked in by dotfiles scripts?
  # maybe we can share somehow so things for nix-y systems and non-nix-y systems alike
  # am I going to _have_ non-nix systems anymore?
}
