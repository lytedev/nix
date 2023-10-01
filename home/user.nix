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
    stateVersion = "23.11";

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
      (pkgs.buildEnv { name = "my-scripts-common"; paths = [ ../scripts/common ]; })
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
          smtpuser = "daniel@lyte.dev";
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

          next-ls = {
            command = "next-ls";
            args = [ "--stdout" ];
          };

          deno = {
            command = "deno";
            args = [ "lsp" ];
            config = { enable = true; lint = true; unstable = true; };
          };
        };

        language = [
          {
            name = "elixir";
            language-servers = [ "elixir-ls" "lexical" "next-ls" ];
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

          {
            name = "javascript";
            language-id = "javascript";
            grammar = "javascript";
            scope = "source.js";
            injection-regex = "^(js|javascript)$";
            file-types = [ "js" "mjs" ];
            shebangs = [ "deno" ];
            language-servers = [ "deno" ];
            roots = [ "deno.jsonc" "deno.json" ];
            formatter = {
              command = "deno";
              args = [ "fmt" ];
            };
            auto-format = true;
            comment-token = "//";
            indent = {
              tab-width = 2;
              unit = "\t";
            };
          }

          {
            name = "typescript";
            language-id = "typescript";
            grammar = "typescript";
            scope = "source.ts";
            injection-regex = "^(ts|typescript)$";
            file-types = [ "ts" ];
            shebangs = [ "deno" ];
            language-servers = [ "deno" ];
            roots = [ "deno.jsonc" "deno.json" ];
            formatter = {
              command = "deno";
              args = [ "fmt" ];
            };
            auto-format = true;
            comment-token = "//";
            indent = {
              tab-width = 2;
              unit = "\t";
            };
          }

          {
            name = "jsonc";
            language-id = "json";
            grammar = "jsonc";
            scope = "source.jsonc";
            injection-regex = "^(jsonc)$";
            roots = [ "deno.jsonc" "deno.json" ];
            file-types = [ "jsonc" ];
            language-servers = [ "deno" ];
            indent = { tab-width = 2; unit = "  "; };
            auto-format = true;
          }

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

    kitty = {
      enable = true;
      darwinLaunchOptions = [ "--single-instance" ];
      shellIntegration = {
        enableFishIntegration = true;
      };
      settings = {
        "font_family" = "IosevkaLyteTerm";
        "bold_font" = "IosevkaLyteTerm Heavy";
        "italic_font" = "IosevkaLyteTerm Italic";
        "bold_italic_font" = "IosevkaLyteTerm Heavy Italic";
        "font_size" = "12.5";
        "inactive_text_alpha" = "0.5";
        "copy_on_select" = true;

        "scrollback_lines" = 500000;

        "symbol_map" = "U+23FB-U+23FE,U+2665,U+26A1,U+2B58,U+E000-U+E00A,U+E0A0-U+E0A3,U+E0B0-U+E0D4,U+E200-U+E2A9,U+E300-U+E3E3,U+E5FA-U+E6AA,U+E700-U+E7C5,U+EA60-U+EBEB,U+F000-U+F2E0,U+F300-U+F32F,U+F400-U+F4A9,U+F500-U+F8FF,U+F0001-U+F1AF0 Symbols Nerd Font Mono";

        # use `kitty + list-fonts --psnames` to get the font's PostScript name

        "allow_remote_control" = true;
        "listen_on" = "unix:/tmp/kitty";
        "repaint_delay" = 3;
        "input_delay" = 3;
        "sync_to_monitor" = true;

        "adjust_line_height" = 0;
        "window_padding_width" = "10.0";
        "window_margin_width" = "0.0";

        "confirm_os_window_close" = 0;

        "enabled_layouts" = "splits:split_axis=vertical,stack";

        "shell_integration" = "disabled";

        "enable_audio_bell" = true;
        "visual_bell_duration" = "0.25";
        "visual_bell_color" = "#333033";

        "url_style" = "single";

        "strip_trailing_spaces" = "smart";

        # open_url_modifiers ctrl

        "tab_bar_align" = "center";
        "tab_bar_style" = "separator";
        "tab_separator" = "";
        "tab_bar_edge" = "top";
        "tab_title_template" = ''{fmt.fg.tab}{fmt.bg.tab} {activity_symbol}{title}'';
        "active_tab_font_style" = "normal";

        ## name: Catppuccin Kitty Mocha
        ## author: Catppuccin Org
        ## license: MIT
        ## upstream: https://github.com/catppuccin/kitty/blob/main/mocha.conf
        ## blurb: Soothing pastel theme for the high-spirited!

        # The basic colors
        "foreground" = "#CDD6F4";
        "background" = "#1E1E2E";
        "selection_foreground" = "#1E1E2E";
        "selection_background" = "#F5E0DC";

        # Cursor colors
        "cursor" = "#F5E0DC";
        "cursor_text_color" = "#1E1E2E";

        # URL underline color when hovering with mouse
        "url_color" = "#F5E0DC";

        # Kitty window border colors
        "active_border_color" = "#74c7ec";
        "inactive_border_color" = "#313244";
        "bell_border_color" = "#F9E2AF";

        # OS Window titlebar colors
        "wayland_titlebar_color" = "system";
        "macos_titlebar_color" = "system";

        # Tab bar colors
        "active_tab_foreground" = "#11111B";
        "active_tab_background" = "#74c7ec";
        "inactive_tab_foreground" = "#CDD6F4";
        "inactive_tab_background" = "#181825";
        "tab_bar_background" = "#11111B";

        # Colors for marks (marked text in the terminal)
        "mark1_foreground" = "#1E1E2E";
        "mark1_background" = "#B4BEFE";
        "mark2_foreground" = "#1E1E2E";
        "mark2_background" = "#74c7ec";
        "mark3_foreground" = "#1E1E2E";
        "mark3_background" = "#74C7EC";

        # The 16 terminal colors

        # black
        "color0" = "#45475A";
        "color8" = "#585B70";

        # red
        "color1" = "#F38BA8";
        "color9" = "#F38BA8";

        # green
        "color2" = "#A6E3A1";
        "color10" = "#A6E3A1";

        # yellow
        "color3" = "#F9E2AF";
        "color11" = "#F9E2AF";

        # blue
        "color4" = "#89B4FA";
        "color12" = "#89B4FA";

        # magenta
        "color5" = "#F5C2E7";
        "color13" = "#F5C2E7";

        # cyan
        "color6" = "#94E2D5";
        "color14" = "#94E2D5";

        # white
        "color7" = "#BAC2DE";
        "color15" = "#A6ADC8";
      };
      keybindings = {
        "ctrl+shift+1" = "change_font_size all 12.5";
        "ctrl+shift+2" = "change_font_size all 18.5";
        "ctrl+shift+3" = "change_font_size all 26";
        "ctrl+shift+4" = "change_font_size all 32";
        "ctrl+shift+5" = "change_font_size all 48";
        "ctrl+shift+o" = "launch --type=tab --stdin-source=@screen_scrollback $EDITOR";

        "ctrl+shift+equal" = "change_font_size all +0.5";
        "ctrl+shift+minus" = "change_font_size all -0.5";

        "shift+insert" = "paste_from_clipboard";
        "ctrl+shift+v" = "paste_from_selection";
        "ctrl+shift+c" = "copy_to_clipboard";

        # kill pane
        "ctrl+shift+q" = "close_window";

        # kill tab
        "ctrl+alt+shift+q" = "close_tab";

        "ctrl+shift+j" = "launch --location=hsplit --cwd=current";
        "ctrl+shift+l" = "launch --location=vsplit --cwd=current";

        "ctrl+alt+shift+k" = "move_window up";
        "ctrl+alt+shift+h" = "move_window left";
        "ctrl+alt+shift+l" = "move_window right";
        "ctrl+alt+shift+j" = "move_window down";

        "ctrl+h" = "neighboring_window left";
        "ctrl+l" = "neighboring_window right";
        "ctrl+k" = "neighboring_window up";
        "ctrl+j" = "neighboring_window down";
        "ctrl+shift+n" = "nth_window -1";
        "ctrl+shift+space>u" = "kitten hints --type=url --program @";

        "ctrl+shift+z" = "toggle_layout stack";
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
      shellAbbrs = { };
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

    eza = {
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

  # maybe we can share somehow so things for nix-y systems and non-nix-y systems alike
  # am I going to _have_ non-nix systems anymore?
}
