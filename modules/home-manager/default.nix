{
  style,
  lib,
  flakeInputs,
  homeManagerModules,
  home-manager,
  home-manager-unstable,
  helix,
  nixosModules,
  pubkey,
  overlays,
}: {
  bat = {
    programs.bat = {
      enable = true;
      config = {
        theme = "ansi";
      };
      /*
      themes = {
        "Catppuccin-mocha" = builtins.readFile (pkgs.fetchFromGitHub
          {
            owner = "catppuccin";
            repo = "bat";
            rev = "477622171ec0529505b0ca3cada68fc9433648c6";
            sha256 = "6WVKQErGdaqb++oaXnY3i6/GuH2FhTgK0v4TN4Y0Wbw=";
          }
          + "/Catppuccin-mocha.tmTheme");
      };
      */
    };

    home.shellAliases = {
      cat = "bat";
    };
  };

  broot = {};

  emacs = {pkgs, ...}: {
    programs.emacs = {
      enable = true;
      /*
      extraConfig = ''
      '';
      */
      extraPackages = epkgs: (with epkgs; [
        magit
      ]);
    };

    programs.fish = {
      shellAliases = {
        e = "emacs";
      };
    };
  };

  cargo = {config, ...}: {
    home.file."${config.home.homeDirectory}/.cargo/config.toml" = {
      enable = true;
      text = ''
        [build]
        rustdocflags = ["--default-theme=ayu"]
      '';
    };

    /*
    home.sessionVariables = {
      RUSTDOCFLAGS = "--default-theme=ayu";
    };
    */
  };

  common = {
    pkgs,
    lib,
    config,
    ...
  }: {
    imports = with homeManagerModules; [
      # nix-colors.homeManagerModules.default
      fish
      bat
      homeManagerModules.helix
      git
      zellij
      htop

      /*
      broot
      nnn
      tmux
      */
    ];

    programs.home-manager.enable = true;

    # services.ssh-agent.enable = true;

    home = {
      username = lib.mkDefault "lytedev";
      homeDirectory = lib.mkDefault "/home/lytedev";
      stateVersion = lib.mkDefault "24.05";

      sessionVariables = {
        EDITOR = "hx";
        VISUAL = "hx";
        PAGER = "less";
        MANPAGER = "less";
      };

      packages = with pkgs; [
        # tools I use when editing nix code
        kanidm
        nil
        alejandra
        gnupg
        (pkgs.buildEnv {
          name = "my-common-scripts";
          paths = [./scripts/common];
        })
      ];
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    programs.skim = {
      # https://github.com/lotabout/skim/issues/494
      enable = false;
      enableFishIntegration = true;
      defaultOptions = ["--no-clear-start" "--color=16"];
    };

    programs.atuin = {
      enable = true;
      enableBashIntegration = config.programs.bash.enable;
      enableFishIntegration = config.programs.fish.enable;
      enableZshIntegration = config.programs.zsh.enable;
      enableNushellIntegration = config.programs.nushell.enable;

      flags = [
        "--disable-up-arrow"
      ];

      settings = {
        auto_sync = true;
        sync_frequency = "1m";
        sync_address = "https://atuin.h.lyte.dev";
        keymap_mode = "vim-insert";
        inline_height = 20;
        show_preview = true;

        sync = {
          records = true;
        };

        dotfiles = {
          enabled = true;
        };
      };
    };

    programs.fzf = {
      # using good ol' fzf until skim sucks less out of the box I guess
      enable = true;
      /*
      enableFishIntegration = true;
      defaultCommand = "fd --type f";
      defaultOptions = ["--height 40%"];
      fileWidgetOptions = ["--preview 'head {}'"];
      */
    };

    # TODO: regular cron or something?
    programs.nix-index = {
      enable = true;

      enableBashIntegration = config.programs.bash.enable;
      enableFishIntegration = config.programs.fish.enable;
      enableZshIntegration = config.programs.zsh.enable;
    };
  };

  desktop = {
    imports = with homeManagerModules; [
      wezterm
    ];
  };

  # ewwbar = {};

  firefox = {pkgs, ...}: {
    programs.firefox = {
      /*
      TODO: this should be able to work on macos, no?
      TODO: enable color scheme/theme by default
      */
      enable = true;

      # TODO: uses nixpkgs.pass so pass otp doesn't work
      package = pkgs.firefox.override {
        nativeMessagingHosts = [
          pkgs.passff-host
          pkgs.plasma-browser-integration
        ];
      };

      /*
      extensions = with pkgs.nur.repos.rycee.firefox-addons; [
        ublock-origin
      ]; # TODO: would be nice to have _all_ my firefox stuff managed here instead of Firefox Sync maybe?
      */

      profiles = {
        daniel = {
          id = 0;
          settings = {
            "general.smoothScroll" = true;
            "browser.zoom.siteSpecific" = true;
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
          '';

          /*
          userContent = ''
          '';
          */
        };
      };
    };
  };

  firefox-no-tabs = {
    programs.firefox = {
      profiles = {
        daniel = {
          userChrome = ''
            #TabsToolbar {
              visibility: collapse;
            }

            #main-window[tabsintitlebar="true"]:not([extradragspace="true"]) #TabsToolbar>.toolbar-items {
              opacity: 0;
              pointer-events: none;
            }

            #main-window:not([tabsintitlebar="true"]) #TabsToolbar {
              visibility: collapse !important;
            }
          '';
        };
      };
    };
  };

  fish = {pkgs, ...}: {
    home = {
      packages = [
        pkgs.gawk # used in prompt
      ];
    };

    programs.eza = {
      enable = true;
    };

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

  git = {lib, ...}: let
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

      /*
      signing = {
        signByDefault = false;
        key = ~/.ssh/personal-ed25519;
      };
      */

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
      lag = {
        wraps = "g";
        body = ''
          lA
          g $argv
        '';
      };
    };
  };

  # gnome = {};

  helix = {
    config,
    pkgs,
    ...
  }: let
    inherit (pkgs) system;
  in {
    # helix rust debugger stuff
    # https://github.com/helix-editor/helix/wiki/Debugger-Configurations
    home.file."${config.xdg.configHome}/lldb_vscode_rustc_primer.py" = {
      text = ''
        import subprocess
        import pathlib
        import lldb

        # Determine the sysroot for the active Rust interpreter
        rustlib_etc = pathlib.Path(subprocess.getoutput('rustc --print sysroot')) / 'lib' / 'rustlib' / 'etc'
        if not rustlib_etc.exists():
            raise RuntimeError('Unable to determine rustc sysroot')

        # Load lldb_lookup.py and execute lldb_commands with the correct path
        lldb.debugger.HandleCommand(f"""command script import "{rustlib_etc / 'lldb_lookup.py'}" """)
        lldb.debugger.HandleCommand(f"""command source -s 0 "{rustlib_etc / 'lldb_commands'}" """)
      '';
    };

    /*
    NOTE: Currently, helix crashes when editing markdown in certain scenarios,
    presumably due to an old markdown treesitter grammar
    https://github.com/helix-editor/helix/issues/9011
    https://github.com/helix-editor/helix/issues/8821
    https://github.com/tree-sitter-grammars/tree-sitter-markdown/issues/114
    */

    programs.helix = {
      enable = true;
      package = lib.mkForce helix.packages.${system}.helix;
      languages = {
        language-server = {
          lexical = {
            command = "lexical";
            args = ["start"];
          };

          /*
          next-ls = {
            command = "next-ls";
            args = ["--stdout"];
          };

          deno = {
            command = "deno";
            args = ["lsp"];
            config = {
              enable = true;
              lint = true;
              unstable = true;
            };
          };
          */
        };

        language = [
          /*
          {
            name = "heex";
            scope = "source.heex";
            injection-regex = "heex";
            language-servers = ["lexical"]; # "lexical" "next-ls" ?
            auto-format = true;
            file-types = ["heex"];
            roots = ["mix.exs" "mix.lock"];
            indent = {
              tab-width = 2;
              unit = "  ";
            };
          }
          {
            name = "elixir";
            language-servers = ["lexical"]; # "lexical" "next-ls" ?
            auto-format = true;
          }
          */
          {
            name = "rust";

            debugger = {
              name = "lldb-vscode";
              transport = "stdio";
              command = "lldb-vscode";
              templates = [
                {
                  name = "binary";
                  request = "launch";
                  completion = [
                    {
                      name = "binary";
                      completion = "filename";
                    }
                  ];
                  args = {
                    program = "{0}";
                    initCommands = ["command script import ${config.xdg.configHome}/lldb_vscode_rustc_primer.py"];
                  };
                }
              ];
            };
          }
          {
            name = "html";
            file-types = ["html"];
            scope = "source.html";
            auto-format = false;
          }
          {
            name = "nix";
            file-types = ["nix"];
            scope = "source.nix";
            auto-format = true;
            formatter = {
              command = "alejandra";
              args = ["-"];
            };
          }
          {
            name = "fish";
            file-types = ["fish"];
            scope = "source.fish";
            auto-format = true;
            indent = {
              tab-width = 2;
              unit = "\t";
            };
          }
          {
            name = "toml";
            file-types = ["toml"];
            scope = "source.toml";
            auto-format = true;
          }

          /*
          {
            name = "javascript";
            language-id = "javascript";
            grammar = "javascript";
            scope = "source.js";
            injection-regex = "^(js|javascript)$";
            file-types = ["js" "mjs"];
            shebangs = ["deno"];
            language-servers = ["deno"];
            roots = ["deno.jsonc" "deno.json"];
            formatter = {
              command = "deno";
              args = ["fmt"];
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
            file-types = ["ts"];
            shebangs = ["deno"];
            language-servers = ["deno"];
            roots = ["deno.jsonc" "deno.json"];
            formatter = {
              command = "deno";
              args = ["fmt"];
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
            roots = ["deno.jsonc" "deno.json"];
            file-types = ["jsonc"];
            language-servers = ["deno"];
            indent = {
              tab-width = 2;
              unit = "  ";
            };
            auto-format = true;
          }
          */
        ];
      };

      settings = {
        theme = "custom";

        editor = {
          soft-wrap.enable = true;
          auto-pairs = false;
          bufferline = "multiple";
          rulers = [81 121];
          cursorline = true;

          /*
          auto-save = false;
          completion-trigger-len = 1;
          color-modes = false;
          scrolloff = 8;
          */

          inline-diagnostics = {
            cursor-line = "hint";
            other-lines = "error";
          };

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
            # display-inlay-hints = true;
          };
          statusline = {
            separator = " ";
            mode = {
              "normal" = "N";
              "insert" = "I";
              "select" = "S";
            };
            left = [
              "file-name"
              "mode"
              /*
              "selections"
              "primary-selection-length"
              "position"
              "position-percentage"
              */
              "spinner"
              "diagnostics"
              "workspace-diagnostics"
            ];
            /*
            center = ["file-name"];
            right = ["version-control" "total-line-numbers" "file-encoding"];
            */
          };
        };
        keys = {
          insert = {
            j = {
              k = "normal_mode";
              j = "normal_mode";
              K = "normal_mode";
              J = "normal_mode";
            };
          };

          normal = {
            "C-k" = "jump_view_up";
            "C-j" = "jump_view_down";
            "C-h" = "jump_view_left";
            "C-l" = "jump_view_right";
            "C-q" = ":quit-all!";
            # "L" = "repeat_last_motion";
            space = {
              q = ":reflow 80";
              Q = ":reflow 120";
              C = ":bc!";
              h = ":toggle lsp.display-inlay-hints";
              # O = ["select_textobject_inner WORD", ":pipe-to xargs xdg-open"];
            };
          };

          select = {
            space = {
              q = ":reflow 80";
              Q = ":reflow 120";
            };
            # "L" = "repeat_last_motion";
          };
        };
      };

      themes = with style.colors.withHashPrefix; {
        custom = {
          "type" = orange;

          "constructor" = blue;

          "constant" = orange;
          "constant.builtin" = orange;
          "constant.character" = yellow;
          "constant.character.escape" = orange;

          "string" = green;
          "string.regexp" = orange;
          "string.special" = blue;

          "comment" = {
            fg = fgdim;
            modifiers = ["italic"];
          };

          "variable" = text;
          "variable.parameter" = {
            fg = red;
            modifiers = ["italic"];
          };
          "variable.builtin" = red;
          "variable.other.member" = text;

          "label" = blue;

          "punctuation" = fgdim;
          "punctuation.special" = blue;

          "keyword" = purple;
          "keyword.storage.modifier.ref" = yellow;
          "keyword.control.conditional" = {
            fg = purple;
            modifiers = ["italic"];
          };

          "operator" = blue;

          "function" = blue;
          "function.macro" = purple;

          "tag" = purple;
          "attribute" = blue;

          "namespace" = {
            fg = blue;
            modifiers = ["italic"];
          };

          "special" = blue;

          "markup.heading.marker" = {
            fg = orange;
            modifiers = ["bold"];
          };
          "markup.heading.1" = blue;
          "markup.heading.2" = yellow;
          "markup.heading.3" = green;
          "markup.heading.4" = orange;
          "markup.heading.5" = red;
          "markup.heading.6" = fg3;
          "markup.list" = purple;
          "markup.bold" = {modifiers = ["bold"];};
          "markup.italic" = {modifiers = ["italic"];};
          "markup.strikethrough" = {modifiers = ["crossed_out"];};
          "markup.link.url" = {
            fg = red;
            modifiers = ["underlined"];
          };
          "markup.link.text" = blue;
          "markup.raw" = red;

          "diff.plus" = green;
          "diff.minus" = red;
          "diff.delta" = blue;

          "ui.linenr" = {fg = fgdim;};
          "ui.linenr.selected" = {fg = fg2;};

          "ui.statusline" = {
            fg = fgdim;
            bg = bg;
          };
          "ui.statusline.inactive" = {
            fg = fg3;
            bg = bg2;
          };
          "ui.statusline.normal" = {
            fg = bg;
            bg = purple;
            modifiers = ["bold"];
          };
          "ui.statusline.insert" = {
            fg = bg;
            bg = green;
            modifiers = ["bold"];
          };
          "ui.statusline.select" = {
            fg = bg;
            bg = red;
            modifiers = ["bold"];
          };

          "ui.popup" = {
            fg = text;
            bg = bg2;
          };
          "ui.window" = {fg = fgdim;};
          "ui.help" = {
            fg = fg2;
            bg = bg2;
          };

          "ui.bufferline" = {
            fg = fgdim;
            bg = bg2;
          };
          "ui.bufferline.background" = {bg = bg2;};

          "ui.text" = text;
          "ui.text.focus" = {
            fg = text;
            bg = bg3;
            modifiers = ["bold"];
          };
          "ui.text.inactive" = {fg = fg2;};

          "ui.virtual" = fg2;
          "ui.virtual.ruler" = {bg = bg3;};
          "ui.virtual.indent-guide" = bg3;
          "ui.virtual.inlay-hint" = {
            fg = bg3;
            bg = bg;
          };

          "ui.selection" = {bg = bg5;};

          "ui.cursor" = {
            fg = bg;
            bg = text;
          };
          "ui.cursor.primary" = {
            fg = bg;
            bg = red;
          };
          "ui.cursor.match" = {
            fg = orange;
            modifiers = ["bold"];
          };

          "ui.cursor.primary.normal" = {
            fg = bg;
            bg = text;
          };
          "ui.cursor.primary.insert" = {
            fg = bg;
            bg = text;
          };
          "ui.cursor.primary.select" = {
            fg = bg;
            bg = text;
          };

          "ui.cursor.normal" = {
            fg = bg;
            bg = fg;
          };
          "ui.cursor.insert" = {
            fg = bg;
            bg = fg;
          };
          "ui.cursor.select" = {
            fg = bg;
            bg = fg;
          };

          "ui.cursorline.primary" = {bg = bg3;};

          "ui.highlight" = {
            bg = bg3;
            fg = bg;
            modifiers = ["bold"];
          };

          "ui.menu" = {
            fg = fg3;
            bg = bg2;
          };
          "ui.menu.selected" = {
            fg = text;
            bg = bg3;
            modifiers = ["bold"];
          };

          "diagnostic.error" = {
            underline = {
              color = red;
              style = "curl";
            };
          };
          "diagnostic.warning" = {
            underline = {
              color = orange;
              style = "curl";
            };
          };
          "diagnostic.info" = {
            underline = {
              color = blue;
              style = "curl";
            };
          };
          "diagnostic.hint" = {
            underline = {
              color = blue;
              style = "curl";
            };
          };

          error = red;
          warning = orange;
          info = blue;
          hint = yellow;
          "ui.background" = {
            bg = bg;
            fg = fgdim;
          };

          /*
          "ui.cursorline.primary" = { bg = "default" }
          "ui.cursorline.secondary" = { bg = "default" }
          */
          "ui.cursorcolumn.primary" = {bg = bg3;};
          "ui.cursorcolumn.secondary" = {bg = bg3;};

          "ui.bufferline.active" = {
            fg = primary;
            bg = bg3;
            underline = {
              color = primary;
              style = "";
            };
          };
        };
      };
    };
  };

  htop = {
    programs.htop = {
      enable = true;
      settings = {
        /*
        hide_kernel_threads = 1;
        hide_userland_threads = 1;
        show_program_path = 0;
        header_margin = 0;
        show_cpu_frequency = 1;
        highlight_base_name = 1;
        tree_view = 0;
        htop_version = "3.2.2";
        config_reader_min_version = 3;
        */
        fields = "0 48 17 18 38 39 40 2 46 47 49 1";
        hide_kernel_threads = 1;
        hide_userland_threads = 1;
        show_program_path = 0;
        header_margin = 0;
        show_cpu_frequency = 1;
        highlight_base_name = 1;
        tree_view = 0;
        hide_running_in_container = 0;
        shadow_other_users = 0;
        show_thread_names = 0;
        highlight_deleted_exe = 1;
        shadow_distribution_path_prefix = 0;
        highlight_megabytes = 1;
        highlight_threads = 1;
        highlight_changes = 0;
        highlight_changes_delay_secs = 5;
        find_comm_in_cmdline = 1;
        strip_exe_from_cmdline = 1;
        show_merged_command = 0;
        screen_tabs = 1;
        detailed_cpu_time = 0;
        cpu_count_from_one = 0;
        show_cpu_usage = 1;
        show_cpu_temperature = 0;
        degree_fahrenheit = 0;
        update_process_names = 0;
        account_guest_in_cpu_meter = 0;
        enable_mouse = 1;
        delay = 15;
        hide_function_bar = 0;
        header_layout = "two_50_50";
        column_meters_0 = "LeftCPUs Memory Swap";
        column_meter_modes_0 = "1 1 1";
        column_meters_1 = "RightCPUs Tasks LoadAverage Uptime";
        column_meter_modes_1 = "1 2 2 2";
        sort_key = 47;
        tree_sort_key = 0;
        sort_direction = -1;
        tree_sort_direction = 1;
        tree_view_always_by_pid = 0;
        all_branches_collapsed = 0;

        /*
        screen:Main=PID USER PRIORITY NICE M_VIRT M_RESIDENT M_SHARE STATE PERCENT_CPU PERCENT_MEM TIME Command
        .sort_key=PERCENT_MEM
        .tree_sort_key=PID
        .tree_view=0
        .tree_view_always_by_pid=0
        .sort_direction=-1
        .tree_sort_direction=1
        .all_branches_collapsed=0

        screen:I/O=PID USER IO_PRIORITY IO_RATE IO_READ_RATE IO_WRITE_RATE Command
        .sort_key=IO_RATE
        .tree_sort_key=PID
        .tree_view=0
        .tree_view_always_by_pid=0
        .sort_direction=-1
        .tree_sort_direction=1
        .all_branches_collapsed=0
        */
      };
    };
  };

  # hyprland = {};

  iex = {
    home.file.".iex.exs" = {
      enable = true;
      text = ''
        Application.put_env(:elixir, :ansi_enabled, true)

        # PROTIP: to break, `#iex:break`

        IEx.configure(
          colors: [enabled: true],
          inspect: [
            pretty: true,
            printable_limit: :infinity,
            limit: :infinity,
            charlists: :as_lists
          ],
          default_prompt: [
            # ANSI CHA, move cursor to column 1
            # "\e[G",
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

  # kitty = {};

  linux = {pkgs, ...}: {
    home = {
      sessionVariables = {
        MOZ_ENABLE_WAYLAND = "1";
      };
    };

    programs.fish = {
      shellAliases = {
        disks = "df -h && lsblk";
        sctl = "sudo systemctl";
        bt = "bluetoothctl";
        pa = "pulsemixer";
        sctlu = "systemctl --user";
      };

      functions = {
        pp = ''
          if test (count $argv) -gt 0
            while true; ping -O -i 1 -w 5 -c 10000000 $argv; sleep 1; end
          else
            while true; ping -O -i 1 -w 5 -c 10000000 1.1.1.1; sleep 1; end
          end
        '';
      };
    };

    home.packages = [
      (pkgs.buildEnv {
        name = "my-linux-scripts";
        paths = [./scripts/linux];
      })
    ];
  };

  linux-desktop-environment-config = {
    pkgs,
    # font,
    ...
  }: {
    imports = with homeManagerModules; [
      linux
      desktop
      firefox
    ];

    gtk.theme = {
      name = "catppuccin-mocha-blue-compact+default";
      package =
        (pkgs.catppuccin-gtk.overrideAttrs {
          src = pkgs.fetchFromGitHub {
            owner = "catppuccin";
            repo = "gtk";
            rev = "v1.0.3";
            fetchSubmodules = true;
            hash = "sha256-q5/VcFsm3vNEw55zq/vcM11eo456SYE5TQA3g2VQjGc=";
          };

          postUnpack = "";
        })
        .override
        {
          accents = ["sapphire"];
          variant = "mocha";
          size = "compact";
        };
    };
    home.pointerCursor = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 40; # TODO: this doesn't seem to work -- at least in Sway
      # some icons are also missing (hand2?)
    };
  };

  macos = {
    imports = with homeManagerModules; [
      desktop
      # password-manager
    ];
  };

  mako = {};

  # nnn = {};

  password-manager = {pkgs, ...}: {
    imports = with homeManagerModules; [
      pass
    ];

    home.packages = with pkgs; [
      passage
      rage
      age-plugin-yubikey
      bitwarden-cli
      oath-toolkit
      # bitwarden-desktop
    ];
  };

  pass = {pkgs, ...}: {
    programs.password-store = {
      enable = true;
      package = pkgs.pass.withExtensions (exts: [exts.pass-otp]);
    };
  };

  senpai = {config, ...}: {
    programs.senpai = {
      enable = true;
      config = {
        address = "irc+insecure://beefcake.hare-cod.ts.net:6667";
        nickname = "lytedev";
        password-cmd = ["pass" "soju"];
      };
    };

    home.file."${config.xdg.configHome}/senpai/senpai.scfg" = {
      enable = true;
      text = ''
        address irc+insecure://beefcake:6667
        nickname lytedev
        password-cmd pass soju
      '';
    };
  };

  sway = {
    imports = [
      {
        _module.args = {
          inherit style;
        };
      }
      ./waybar.nix
      ./mako.nix
      ./swaylock.nix
      ./sway.nix
    ];
  };

  /*
  sway-laptop = {};
  swaylock = {};
  tmux = {};
  wallpaper-manager = {};
  waybar = {};
  */

  wezterm = {
    pkgs,
    # font,
    ...
  }: {
    # docs: https://wezfurlong.org/wezterm/config/appearance.html#defining-your-own-colors
    programs.wezterm = with style.colors.withHashPrefix; {
      enable = true;
      # package = pkgs.wezterm;
      extraConfig = builtins.readFile ./wezterm/config.lua;
      colorSchemes = {
        catppuccin-mocha-sapphire = {
          ansi = map (x: style.colors.withHashPrefix.${toString x}) (pkgs.lib.lists.range 0 7);
          brights = map (x: style.colors.withHashPrefix.${toString (x + 8)}) (pkgs.lib.lists.range 0 7);

          foreground = fg;
          background = bg;

          cursor_fg = bg;
          cursor_bg = text;
          cursor_border = text;

          selection_fg = bg;
          selection_bg = yellow;

          scrollbar_thumb = bg2;

          split = bg5;

          # indexed = { [136] = '#af8700' },
          tab_bar = {
            background = bg3;

            active_tab = {
              bg_color = primary;
              fg_color = bg;
              italic = false;
            };
            inactive_tab = {
              bg_color = bg2;
              fg_color = fgdim;
              italic = false;
            };
            inactive_tab_hover = {
              bg_color = bg3;
              fg_color = primary;
              italic = false;
            };
            new_tab = {
              bg_color = bg2;
              fg_color = fgdim;
              italic = false;
            };
            new_tab_hover = {
              bg_color = bg3;
              fg_color = primary;
              italic = false;
            };
          };

          compose_cursor = orange;

          /*
          copy_mode_active_highlight_bg = { Color = '#000000' },
          copy_mode_active_highlight_fg = { AnsiColor = 'Black' },
          copy_mode_inactive_highlight_bg = { Color = '#52ad70' },
          copy_mode_inactive_highlight_fg = { AnsiColor = 'White' },

          quick_select_label_bg = { Color = 'peru' },
          quick_select_label_fg = { Color = '#ffffff' },
          quick_select_match_bg = { AnsiColor = 'Navy' },
          quick_select_match_fg = { Color = '#ffffff' },
          */
        };
      };
    };
  };

  zellij = {lib, ...}: {
    # zellij does not support modern terminal keyboard input:
    # https://github.com/zellij-org/zellij/issues/735
    programs.zellij = {
      # uses home manager's toKDL generator
      enable = true;
      # This causes fish to start zellij immediately
      # enableFishIntegration = true;
      settings = {
        pane_frames = false;
        simplified_ui = true;
        default_mode = "locked";
        mouse_mode = true;
        copy_clipboard = "primary";
        copy_on_select = true;
        mirror_session = false;

        keybinds = with builtins; let
          binder = bind: let
            keys = elemAt bind 0;
            action = elemAt bind 1;
            argKeys = map (k: "\"${k}\"") (lib.lists.flatten [keys]);
          in {
            name = "bind ${concatStringsSep " " argKeys}";
            value = action;
          };
          layer = binds: (listToAttrs (map binder binds));
        in {
          # _props = {clear-defaults = true;};
          normal = {};
          locked = layer [
            [["Ctrl g"] {SwitchToMode = "Normal";}]
            [["Ctrl L"] {NewPane = "Right";}]
            [["Ctrl Z"] {NewPane = "Right";}]
            [["Ctrl J"] {NewPane = "Down";}]
            [["Ctrl h"] {MoveFocus = "Left";}]
            [["Ctrl l"] {MoveFocus = "Right";}]
            [["Ctrl j"] {MoveFocus = "Down";}]
            [["Ctrl k"] {MoveFocus = "Up";}]
          ];
          resize = layer [
            [["Ctrl n"] {SwitchToMode = "Normal";}]
            [["h" "Left"] {Resize = "Increase Left";}]
            [["j" "Down"] {Resize = "Increase Down";}]
            [["k" "Up"] {Resize = "Increase Up";}]
            [["l" "Right"] {Resize = "Increase Right";}]
            [["H"] {Resize = "Decrease Left";}]
            [["J"] {Resize = "Decrease Down";}]
            [["K"] {Resize = "Decrease Up";}]
            [["L"] {Resize = "Decrease Right";}]
            [["=" "+"] {Resize = "Increase";}]
            [["-"] {Resize = "Decrease";}]
          ];
          pane = layer [
            [["Ctrl p"] {SwitchToMode = "Normal";}]
            [["h" "Left"] {MoveFocus = "Left";}]
            [["l" "Right"] {MoveFocus = "Right";}]
            [["j" "Down"] {MoveFocus = "Down";}]
            [["k" "Up"] {MoveFocus = "Up";}]
            [["p"] {SwitchFocus = [];}]
            [
              ["n"]
              {
                NewPane = [];
                SwitchToMode = "Normal";
              }
            ]
            [
              ["d"]
              {
                NewPane = "Down";
                SwitchToMode = "Normal";
              }
            ]
            [
              ["r"]
              {
                NewPane = "Right";
                SwitchToMode = "Normal";
              }
            ]
            [
              ["x"]
              {
                CloseFocus = [];
                SwitchToMode = "Normal";
              }
            ]
            [
              ["f"]
              {
                ToggleFocusFullscreen = [];
                SwitchToMode = "Normal";
              }
            ]
            [
              ["z"]
              {
                TogglePaneFrames = [];
                SwitchToMode = "Normal";
              }
            ]
            [
              ["w"]
              {
                ToggleFloatingPanes = [];
                SwitchToMode = "Normal";
              }
            ]
            [
              ["e"]
              {
                TogglePaneEmbedOrFloating = [];
                SwitchToMode = "Normal";
              }
            ]
            [
              ["c"]
              {
                SwitchToMode = "RenamePane";
                PaneNameInput = 0;
              }
            ]
          ];
          move = layer [
            [["Ctrl h"] {SwitchToMode = "Normal";}]
            [["n" "Tab"] {MovePane = [];}]
            [["p"] {MovePaneBackwards = [];}]
            [["h" "Left"] {MovePane = "Left";}]
            [["j" "Down"] {MovePane = "Down";}]
            [["k" "Up"] {MovePane = "Up";}]
            [["l" "Right"] {MovePane = "Right";}]
          ];
          tab = layer [
            [["Ctrl t"] {SwitchToMode = "Normal";}]
            [
              ["r"]
              {
                SwitchToMode = "RenameTab";
                TabNameInput = 0;
              }
            ]
            [["h" "Left" "Up" "k"] {GoToPreviousTab = [];}]
            [["l" "Right" "Down" "j"] {GoToNextTab = [];}]
            [
              ["n"]
              {
                NewTab = [];
                SwitchToMode = "Normal";
              }
            ]
            [
              ["x"]
              {
                CloseTab = [];
                SwitchToMode = "Normal";
              }
            ]
            [
              ["s"]
              {
                ToggleActiveSyncTab = [];
                SwitchToMode = "Normal";
              }
            ]
            [
              ["1"]
              {
                GoToTab = 1;
                SwitchToMode = "Normal";
              }
            ]
            [
              ["2"]
              {
                GoToTab = 2;
                SwitchToMode = "Normal";
              }
            ]
            [
              ["3"]
              {
                GoToTab = 3;
                SwitchToMode = "Normal";
              }
            ]
            [
              ["4"]
              {
                GoToTab = 4;
                SwitchToMode = "Normal";
              }
            ]
            [
              ["5"]
              {
                GoToTab = 5;
                SwitchToMode = "Normal";
              }
            ]
            [
              ["6"]
              {
                GoToTab = 6;
                SwitchToMode = "Normal";
              }
            ]
            [
              ["7"]
              {
                GoToTab = 7;
                SwitchToMode = "Normal";
              }
            ]
            [
              ["8"]
              {
                GoToTab = 8;
                SwitchToMode = "Normal";
              }
            ]
            [
              ["9"]
              {
                GoToTab = 9;
                SwitchToMode = "Normal";
              }
            ]
            [["Tab"] {ToggleTab = [];}]
          ];
          scroll = layer [
            [["Ctrl s"] {SwitchToMode = "Normal";}]
            [
              ["e"]
              {
                EditScrollback = [];
                SwitchToMode = "Normal";
              }
            ]
            [
              ["s"]
              {
                SwitchToMode = "EnterSearch";
                SearchInput = 0;
              }
            ]
            [
              ["Ctrl c"]
              {
                ScrollToBottom = [];
                SwitchToMode = "Normal";
              }
            ]
            [["j" "Down"] {ScrollDown = [];}]
            [["k" "Up"] {ScrollUp = [];}]
            [["Ctrl f" "PageDown" "Right" "l"] {PageScrollDown = [];}]
            [["Ctrl b" "PageUp" "Left" "h"] {PageScrollUp = [];}]
            [["d"] {HalfPageScrollDown = [];}]
            [["u"] {HalfPageScrollUp = [];}]
            # uncomment this and adjust key if using copy_on_select=false
            # bind "Alt c" { Copy; }
          ];
          search = layer [
            [["Ctrl s"] {SwitchToMode = "Normal";}]
            [
              ["Ctrl c"]
              {
                ScrollToBottom = [];
                SwitchToMode = "Normal";
              }
            ]
            [["j" "Down"] {ScrollDown = [];}]
            [["k" "Up"] {ScrollUp = [];}]
            [["Ctrl f" "PageDown" "Right" "l"] {PageScrollDown = [];}]
            [["Ctrl b" "PageUp" "Left" "h"] {PageScrollUp = [];}]
            [["d"] {HalfPageScrollDown = [];}]
            [["u"] {HalfPageScrollUp = [];}]
            [["n"] {Search = "down";}]
            [["p"] {Search = "up";}]
            [["c"] {SearchToggleOption = "CaseSensitivity";}]
            [["w"] {SearchToggleOption = "Wrap";}]
            [["o"] {SearchToggleOption = "WholeWord";}]
          ];
          entersearch = layer [
            [["Ctrl c" "Esc"] {SwitchToMode = "Scroll";}]
            [["Enter"] {SwitchToMode = "Search";}]
          ];
          renametab = layer [
            [["Ctrl c"] {SwitchToMode = "Normal";}]
            [
              ["Esc"]
              {
                UndoRenameTab = [];
                SwitchToMode = "Tab";
              }
            ]
          ];
          renamepane = layer [
            [["Ctrl c"] {SwitchToMode = "Normal";}]
            [
              ["Esc"]
              {
                UndoRenamePane = [];
                SwitchToMode = "Pane";
              }
            ]
          ];
          session = layer [
            [["Ctrl o"] {SwitchToMode = "Normal";}]
            [["Ctrl s"] {SwitchToMode = "Scroll";}]
            [["d"] {Detach = [];}]
          ];
          tmux = layer [
            [["["] {SwitchToMode = "Scroll";}]
            [
              ["Ctrl b"]
              {
                Write = 2;
                SwitchToMode = "Normal";
              }
            ]
            [
              ["\\\""]
              {
                NewPane = "Down";
                SwitchToMode = "Normal";
              }
            ]
            [
              ["%"]
              {
                NewPane = "Right";
                SwitchToMode = "Normal";
              }
            ]
            [
              ["z"]
              {
                ToggleFocusFullscreen = [];
                SwitchToMode = "Normal";
              }
            ]
            [
              ["c"]
              {
                NewTab = [];
                SwitchToMode = "Normal";
              }
            ]
            [[","] {SwitchToMode = "RenameTab";}]
            [
              ["p"]
              {
                GoToPreviousTab = [];
                SwitchToMode = "Normal";
              }
            ]
            [
              ["n"]
              {
                GoToNextTab = [];
                SwitchToMode = "Normal";
              }
            ]
            [
              ["Left"]
              {
                MoveFocus = "Left";
                SwitchToMode = "Normal";
              }
            ]
            [
              ["Right"]
              {
                MoveFocus = "Right";
                SwitchToMode = "Normal";
              }
            ]
            [
              ["Down"]
              {
                MoveFocus = "Down";
                SwitchToMode = "Normal";
              }
            ]
            [
              ["Up"]
              {
                MoveFocus = "Up";
                SwitchToMode = "Normal";
              }
            ]
            [
              ["h"]
              {
                MoveFocus = "Left";
                SwitchToMode = "Normal";
              }
            ]
            [
              ["l"]
              {
                MoveFocus = "Right";
                SwitchToMode = "Normal";
              }
            ]
            [
              ["j"]
              {
                MoveFocus = "Down";
                SwitchToMode = "Normal";
              }
            ]
            [
              ["k"]
              {
                MoveFocus = "Up";
                SwitchToMode = "Normal";
              }
            ]
            [["o"] {FocusNextPane = [];}]
            [["d"] {Detach = [];}]
            [["Space"] {NextSwapLayout = [];}]
            [
              ["x"]
              {
                CloseFocus = [];
                SwitchToMode = "Normal";
              }
            ]
          ];
          "shared_except \"locked\"" = layer [
            [["Ctrl g"] {SwitchToMode = "Locked";}]
            [["Ctrl q"] {Quit = [];}]
            [["Alt n"] {NewPane = [];}]
            [["Alt h" "Alt Left"] {MoveFocusOrTab = "Left";}]
            [["Alt l" "Alt Right"] {MoveFocusOrTab = "Right";}]
            [["Alt j" "Alt Down"] {MoveFocus = "Down";}]
            [["Alt k" "Alt Up"] {MoveFocus = "Up";}]
            [["Alt ]" "Alt +"] {Resize = "Increase";}]
            [["Alt -"] {Resize = "Decrease";}]
            [["Alt ["] {PreviousSwapLayout = [];}]
            [["Alt ]"] {NextSwapLayout = [];}]
          ];
          "shared_except \"normal\" \"locked\"" = layer [
            [["Enter" "Esc"] {SwitchToMode = "Normal";}]
          ];
          "shared_except \"pane\" \"locked\"" = layer [
            [["Ctrl p"] {SwitchToMode = "Pane";}]
          ];
          "shared_except \"resize\" \"locked\"" = layer [
            [["Ctrl n"] {SwitchToMode = "Resize";}]
          ];
          "shared_except \"scroll\" \"locked\"" = layer [
            [["Ctrl s"] {SwitchToMode = "Scroll";}]
          ];
          "shared_except \"session\" \"locked\"" = layer [
            [["Ctrl o"] {SwitchToMode = "Session";}]
          ];
          "shared_except \"tab\" \"locked\"" = layer [
            [["Ctrl t"] {SwitchToMode = "Tab";}]
          ];
          "shared_except \"move\" \"locked\"" = layer [
            [["Ctrl h"] {SwitchToMode = "Move";}]
          ];
          "shared_except \"tmux\" \"locked\"" = layer [
            [["Ctrl b"] {SwitchToMode = "Tmux";}]
          ];
        };

        default_layout = "compact";
        theme = "match";

        themes = {
          match = with style.colors.withHashPrefix; {
            fg = fg;
            bg = bg;

            black = bg;
            white = fg;

            red = red;
            green = green;
            yellow = yellow;
            blue = blue;
            magenta = purple;
            cyan = blue;
            orange = orange;
          };
        };
        # TODO: port config

        plugins = {
          /*
          tab-bar = {path = "tab-bar";};
          compact-bar = {path = "compact-bar";};
          */
        };

        ui = {
          pane_frames = {
            rounded_corners = true;
            hide_session_name = true;
          };
        };
      };
    };

    home.shellAliases = {
      z = "zellij";
    };
  };
}
