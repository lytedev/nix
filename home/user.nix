{ pkgs, lib, ... }:
let
  email = "daniel@lyte.dev";
  name = "Daniel Flanagan";
in
{
  # TODO: email access?
  # accounts.email.accounts = {
  #   google = {
  #     address = "wraithx2@gmail.com";
  #   };
  # };

  home = {
    username = lib.mkDefault "daniel";
    homeDirectory = lib.mkDefault "/home/daniel/.home";
    stateVersion = "23.05";

    packages = [
      # I use rtx for managing the following programs' versions instead of nix:
      # kubectl, aws
      pkgs.rtx

      # text editor
      pkgs.helix

      # I need gawk for my fish prompt
      pkgs.gawk

      pkgs.nil
      pkgs.nixpkgs-fmt

      # TODO: os-specific scripts? macOS versus Linux (arch or nixos? do I need to distinguish at that point?)
      (pkgs.buildEnv { name = "my-scripts"; paths = [ ../scripts ]; })
    ];

    file = {
      ".iex.exs" = {
        enable = true;
        text = ''
          Application.put_env(:elixir, :ansi_enabled, true)

          # PROTIP: to break, `#iex:break`

          IEx.configure(
            colors: [enabled: true],
            inspect: [
              pretty: true,
              printable_limit: :infinity,
              limit: :infinity
            ],
            default_prompt:
              [
                # ANSI CHA, move cursor to column 1
                "\e[G",
                :magenta,
                # IEx prompt variable
                "%prefix",
                "#",
            # IEx prompt variable
            "%counter",
            # plain string
            ">",
            :reset
            ]
            |> IO.ANSI.format()
            |> IO.chardata_to_string()
            )
        '';
      };
    };
  };

  programs = {
    password-store = {
      enable = true;
      package = (pkgs.pass.withExtensions (exts: [ exts.pass-otp ]));
    };

    git = {
      enable = true;

      userEmail = email;
      userName = name;

      delta = {
        enable = true;
        options = { };
      };

      lfs = {
        enable = true;
      };

      signing = {
        signByDefault = true;
        key = "daniel@lyte.dev";
      };

      extraConfig = {
        push = {
          autoSetupRemote = true;
        };

        branch = {
          autoSeupMerge = true;
        };

        sendemail = {
          smtpserver = "smtp.mailgun.org";
          smtpuser = "daniel@lyte.dev";
          smtrpencryption = "tls";
          smtpserverport = 587;
        };

        url = {
          "git@git.hq.bill.com:" = {
            insteadOf = "https://git.hq.bill.com";
          };
        };

        aliases = {
          a = "add";
          A = "add - A";
          ac = "commit - a";
          b = "rev-parse - -symbolic-full-name HEAD";
          c = "commit";
          cm = "commit - m";
          cnv = "commit - -no-verify";
          co = "checkoutd";
          d = "diff";
          ds = "diff - -staged";
          dt = "difftool ";
          f = "fetch";
          l = "log - -graph - -abbrev-commit - -decorate - -oneline - -all";
          plainlog = " log - -pretty=format:'%h %ad%x09%an%x09%s' --date=short --decorate";
          ls = "ls-files";
          mm = "merge master";
          p = "push";
          pf = "push --force-with-lease";
          pl = "pull";
          rim = "rebase -i master";
          s = "status";
          sur = "submodule update --remote";
        };
      };
    };

    gitui = {
      enable = true;
    };

    helix = {
      enable = true;
      package = pkgs.helix;
      languages = {
        language-server = {
          lexical = {
            command = "lexical";
            args = [ "start" ];
          };
        };

        language = [
          {
            name = "elixir";
            language-servers = [ "elixir-ls" "lexical" ];
            auto-format = true;
          }
          {
            name = "html";
            auto-format = false;
          }
          {
            name = "nix";
            auto-format = true;
            formatter = {
              command = "nixpkgs-fmt";
              args = [ ];
            };
          }
          {
            name = "fish";
            auto-format = true;
            indent = {
              tab-width = 2;
              unit = "\t";
            };
          }
          # TODO: deno:
          #[[language]]
          #name = "javascript"
          #scope = "source.js"
          #injection-regex = "^(js|javascript)$"
          #file-types = [ "js", "jsx", "mjs" ]
          #shebangs = [ "deno", "node" ]
          #roots = [ "deno.jsonc", "deno.json", "package.json", "tsconfig.json" ]
          #comment-token = "//"
          # config = { enable = true, lint = true, unstable = true }
          # language-server = { command = "typescript-language-server", args = ["--stdio"], language-id = "javascript" }
          #indent = {
          #tab-width = 2, unit = "\t" }
          #auto-format = true

          # [[language]]
          # name = "jsx"
          # scope = "source.jsx"
          # injection-regex = "jsx"
          # file-types = ["jsx"]
          # shebangs = ["deno", "node"]
          # roots = ["deno.jsonc", "deno.json", "package.json", "tsconfig.json"]
          # comment-token = "//"
          # config = { enable = true, lint = true, unstable = true }
          # language-server = { command = "deno", args = ["lsp"], language-id = "javascriptreact" }
          # indent = { tab-width = 2, unit = "  " }
          # grammar = "javascript"
          # auto-format = true

          # [[language]]
          # name = "typescript"
          # scope = "source.ts"
          # injection-regex = "^(ts|typescript)$"
          # file-types = ["ts"]
          # shebangs = ["deno", "node"]
          # roots = ["deno.jsonc", "deno.json", "package.json", "tsconfig.json"]
          # config = { enable = true, lint = true, unstable = true }
          # language-server = { command = "deno", args = ["lsp"], language-id = "typescript" }
          # indent = { tab-width = 2, unit = "  " }
          # auto-format = true

          # [[language]]
          # name = "tsx"
          # scope = "source.tsx"
          # injection-regex = "^(tsx)$" # |typescript
          # file-types = ["tsx"]
          # shebangs = ["deno", "node"]
          # roots = ["deno.jsonc", "deno.json", "package.json", "tsconfig.json"]
          # config = { enable = true, lint = true, unstable = true }
          # language-server = { command = "deno", args = ["lsp"], language-id = "typescriptreact" }
          # indent = { tab-width = 2, unit = "  " }
          # auto-format = true

          # [[language]]
          # name = "jsonc"
          # scope = "source.jsonc"
          # injection-regex = "^(jsonc)$"
          # file-types = ["jsonc"]
          # shebangs = ["deno", "node"]
          # roots = ["deno.jsonc", "deno.json", "package.json", "tsconfig.json"]
          # config = { enable = true, lint = true, unstable = true }
          # language-server = { command = "deno", args = ["lsp"], language-id = "jsonc" }
          # indent = { tab-width = 2, unit = "  " }
          # auto-format = true
        ];
      };

      settings = {
        theme = "custom";

        editor = {
          soft-wrap.enable = true;
          auto-pairs = false;
          auto-save = false;
          completion-trigger-len = 1;
          color-modes = false;
          bufferline = "multiple";
          scrolloff = 8;
          rulers = [ 80 120 ];
          cursorline = true;

          cursor-shape = {
            normal = "block";
            insert = "bar";
            select = "underline";
          };

          file-picker.hidden = false;
          indent-guides = {
            render = true;
            character = "▏";
          };

          lsp = {
            display-messages = true;
            display-inlay-hints = true;
          };
          statusline = {
            left = [ "mode" "spinner" "selections" "primary-selection-length" "position" "position-percentage" "diagnostics" "workspace-diagnostics" ];
            center = [ "file-name" ];
            right = [ "version-control" "total-line-numbers" "file-encoding" ];
          };

        };
        keys = {

          insert = {
            j = { k = "normal_mode"; j = "normal_mode"; K = "normal_mode"; J = "normal_mode"; };
          };

          normal = {
            D = "kill_to_line_end";
            "^" = "goto_line_start";
            "C-k" = "jump_view_up";
            "C-j" = "jump_view_down";
            "C-h" = "jump_view_left";
            "C-l" = "jump_view_right";
            "C-q" = ":quit-all!";
            "L" = "repeat_last_motion";
            space = {
              q = ":reflow 80";
              Q = ":reflow 120";
              v = ":run-shell-command fish -c 'env > /tmp/env'";
              C = ":bc!";
              h = ":toggle lsp.display-inlay-hints";
              # O = ["select_textobject_inner WORD", ":pipe-to xargs xdg-open"];
            };
          };


          select = {
            space = { q = ":reflow 80"; Q = ":reflow 120"; };
            "L" = "repeat_last_motion";
          };
        };
      };

      themes = {
        custom = {
          "inherits" = "catppuccin_mocha";

          "ui.background" = "default";

          # "ui.cursorline.primary" = { bg = "default" }
          # "ui.cursorline.secondary" = { bg = "default" }
          # "ui.cursorcolumn.primary" = { bg = "default" }
          # "ui.cursorcolumn.secondary" = { bg = "default" }
          # "ui.virtual.ruler" = { bg = "default" }

          "ui.bufferline.active" = {
            fg = "sapphire";
            bg = "base";
            underline = {
              color = "sapphire";
              style = "";
            };
          };
        };
      };
    };

    bat = {
      enable = true;
      config = {
        theme = "Catppuccin-mocha";
      };
      themes = {
        "Catppuccin-mocha" = builtins.readFile (pkgs.fetchFromGitHub
          {
            owner = "catppuccin";
            repo = "bat";
            rev = "477622171ec0529505b0ca3cada68fc9433648c6";
            sha256 = "6WVKQErGdaqb++oaXnY3i6/GuH2FhTgK0v4TN4Y0Wbw=";
          } + "/Catppuccin-mocha.tmTheme");
      };
    };

    zellij = {
      # TODO: enable after port config
      enable = false;
      enableFishIntegration = true;
      settings = {
        # TODO: port config
      };
    };

    broot = {
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

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    fish = {
      enable = true;
      # I load long scripts from files for a better editing experience
      shellInit = builtins.readFile ../fish/shellInit.fish;
      interactiveShellInit = builtins.readFile ../fish/interactiveShellInit.fish;
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
        p = "ping";
        dc = "docker compose";
        k = "kubectl";
        kg = "kubectl get";
        v = "$EDITOR";
        sv = "sudo $EDITOR";
        kssh = "kitty +kitten ssh";
      };
    };

    exa = {
      enable = true;
    };

    skim = {
      enable = true;
      enableFishIntegration = true;
    };

    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };
  };

  # wayland.windowManager.sway = {
  #   enable = true;
  # }; # TODO: would be nice to have my sway config declared here instead of symlinked in by dotfiles scripts?
  # maybe we can share somehow so things for nix-y systems and non-nix-y systems alike
  # am I going to _have_ non-nix systems anymore?
}



