{ self, slippi, ... }@inputs:
let
  inherit (self) outputs;
  inherit (outputs) homeManagerModules style;
  inherit (self.flakeLib) conditionalOutOfStoreSymlink;
in
{
  default =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      imports = with homeManagerModules; [
        slippi.homeManagerModules.default
        shell
        fish
        helix
        git
        jujutsu
        zellij
        htop
        linux
        sshconfig
        senpai
        iex
        cargo
        desktop
        gnome

        /*
          broot
          nnn
          tmux
        */
      ];

      config = {
        slippi-launcher.enable = lib.mkDefault false;
      };
    };

  shell =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      options = {
        lyte = {
          useOutOfStoreSymlinks = {
            enable = lib.mkEnableOption "Enable the use of mkOutOfStoreSymlink for certain configuration files for faster editing, but means /etc/nixos and /etc/nix/flake must point to this flake in order to work";
          };
          shell = {
            enable = lib.mkEnableOption "Enable home-manager shell configuration for the user";
            learn-jujutsu-not-git = {
              enable = lib.mkEnableOption "Soft-disable the 'git' command in an effort to force me to learn jujutsu (jj)";
            };
          };
        };
      };

      config = lib.mkIf config.lyte.shell.enable {
        programs.fish.enable = true;
        programs.helix.enable = true;
        programs.zellij.enable = lib.mkDefault false;
        programs.eza.enable = true;
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

        programs.home-manager.enable = true;

        programs.direnv.mise = {
          enable = true;
        };

        programs.mise = {
          enable = lib.mkDefault false;
          enableFishIntegration = config.programs.mise.enable && config.programs.fish.enable;
          enableBashIntegration = config.programs.mise.enable && config.programs.bash.enable;
          enableZshIntegration = config.programs.mise.enable && config.programs.zsh.enable;
        };

        programs.jujutsu = {
          enable = true;
        };

        programs.jq = {
          enable = true;
        };

        programs.btop = {
          enable = true;
          package = pkgs.btop.override {
            rocmSupport = true;
          };
        };

        # services.ssh-agent.enable = true;

        home = {
          sessionVariables = {
            TERMINAL = "ghostty";
            EDITOR = "hx";
            VISUAL = "hx";
            PAGER = "less";
            MANPAGER = "less";
          };

          packages = with pkgs; [
            nixfmt-rfc-style
            nixd
            nil
            (pkgs.buildEnv {
              name = "my-common-scripts";
              paths = [ ./scripts/common ];
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
          defaultOptions = [
            "--no-clear-start"
            "--color=16"
            "--height=20"
          ];
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
    };

  cargo =
    { config, ... }:
    {
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

  desktop =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      types = lib.types;
    in
    {
      imports = with homeManagerModules; [
        firefox
        ghostty
      ];
      options = {
        lyte = {
          desktop = {
            enable = lib.mkEnableOption "Enable my default desktop configuration and applications";
            environment = lib.mkOption {
              type = types.enum [
                "gnome"
                "plasma"
              ];
              default = "gnome";
            };
            extraEnvironments = lib.mkOption {
              default = [ ];
            };
          };
        };
      };
      config = lib.mkIf config.lyte.desktop.enable {
        programs.firefox.enable = true;
        programs.ghostty.enable = true;
        home.pointerCursor = {
          name = "Bibata-Modern-Classic";
          package = pkgs.bibata-cursors;
          size = 40;
        };
        gtk.cursorTheme = {
          name = "Bibata-Modern-Classic";
          package = pkgs.bibata-cursors;
          size = 40;
        };
        # gtk.font = pkgs.iosevkaLyteTerm;
      };
    };

  firefox = import ./firefox.nix;
  fish = import ./fish.nix;

  jujutsu =
    {
      fullName,
      config,
      lib,
      ...
    }:
    let
      email = config.accounts.email.accounts.primary.address;

    in
    {
      config = {
        programs.jujutsu = {
          enable = true;
          settings = {
            user = {
              inherit email;
              name = fullName;
            };
            ui = {
              paginate = "never";
            };
            template-aliases = {
              "format_timestamp(timestamp)" = "timestamp.ago()";
            };
            templates = {
              draft_commit_description = ''
                concat(
                  coalesce(description, "\n"),
                  surround(
                    "\nJJ: This commit contains the following changes:\n", "",
                    indent("JJ:     ", diff.stat(72)),
                  ),
                  "\nJJ: ignore-rest\n",
                  diff.git(),
                )
              '';
            };
          };
        };
      };
    };

  git =
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

        userName = lib.mkDefault fullName;
        userEmail = email;

        delta = {
          enable = true;
          options = { };
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

          url = {
            # TODO: how to have per-machine not-in-git configuration?
            "git@git.hq.bill.com:" = {
              insteadOf = "https://git.hq.bill.com";
            };
          };
        };
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
    };

  plasma =
    {
      lib,
      config,
      ...
    }:
    {
      config = lib.mkIf (config.lyte.desktop.enable && (config.lyte.desktop.environment == "plasma")) {
        dconf.enable = true;
      };
    };

  niri =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {
      # imports = [ inputs.niri.homeModules.niri ];
      config =
        lib.mkIf
          (
            config.lyte.desktop.enable
            && (
              config.lyte.desktop.environment == "niri"
              || builtins.elem "niri" config.lyte.desktop.extraEnvironments
            )
          )
          {
            # programs.niri.enable = true;
            home = {
              packages = with pkgs; [
                fuzzel
                swaybg
                swaylock
                swayosd
                waybar
              ];
            };

            home.file."${config.xdg.configHome}/niri" = {
              source = conditionalOutOfStoreSymlink config /etc/nix/flake/lib/modules/home/niri ./niri;
            };
          };
    };

  gnome =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {
      config = lib.mkIf (config.lyte.desktop.enable && (config.lyte.desktop.environment == "gnome")) {
        dconf = {
          enable = true;
          settings = {
            "org/gnome/desktop/input-sources" = {
              xkb-options = [ "caps:ctrl_modifier" ];
            };
            "org/gnome/settings-daemon/plugins/media-keys" = {
              screensaver = [ "<Shift><Control><Super>l" ]; # lock screen
              mic-mute = [ "<Shift><Super>v" ];
            };
            "org/gnome/desktop/default-applications/terminal" = {
              exec = "ghostty";
            };
            "org/gnome/desktop/peripherals/touchpad" = {
              disable-while-typing = false;
            };
            "org/gnome/desktop/peripherals/keyboard" = {
              # gnome key repeat
              repeat = true;
              repeat-interval = lib.hm.gvariant.mkUint32 10;
              delay = lib.hm.gvariant.mkUint32 200;
            };

            "org/gnome/desktop/wm/preferences" = {
              resize-with-right-button = true;
              # mouse-button-modifier = '<Super>'; # default
            };
            "org/gnome/desktop/wm/keybindings" = {
              minimize = [ "<Shift><Control><Super>h" ];
              show-desktop = [ "<Super>d" ];
              move-to-workspace-left = [ "<Super><Shift>h" ];
              move-to-workspace-right = [ "<Super><Shift>l" ];
              switch-to-workspace-left = [ "<Super><Control>h" ];
              switch-to-workspace-right = [ "<Super><Control>l" ];
              # mouse-button-modifier = '<Super>'; # default
            };
            "org/gnome/desktop/interface" = {
              show-battery-percentage = true;
              clock-show-weekday = true;
              # font-name = "IosevkaLyteTerm 12";
              # monospace-font-name = "IosevkaLyteTerm 12";
              color-scheme = "prefer-dark";
              # scaling-factor = 1.75;
            };
            "org/gnome/mutter" = {
              experimental-features = [ "variable-refresh-rate" ];
            };

            "org/gnome/shell" = {
              disable-user-extensions = false;
              enabled-extensions = with pkgs.gnomeExtensions; [
                tiling-shell.extensionUuid
                appindicator.extensionUuid
                blur-my-shell.extensionUuid
              ];
            };

            "org/gnome/shell/extensions/tilingshell" = {
              inner-gaps = 8;
              outer-gaps = 8;
              window-border-width = 2;
              window-border-color = "rgba(116,199,236,0.47)";
              focus-window-right = [ "<Super>l" ];
              focus-window-left = [ "<Super>h" ];
              focus-window-up = [ "<Super>k" ];
              focus-window-down = [ "<Super>j" ];
            };
          };
        };

        home = {
          packages = with pkgs.gnomeExtensions; [
            tiling-shell
            blur-my-shell
            appindicator
          ];
        };

        programs.gnome-shell = {
          enable = true;
          extensions =
            [ { package = pkgs.gnomeExtensions.gsconnect; } ]
            ++ map (p: { package = p; }) (
              with pkgs.gnomeExtensions;
              [
                tiling-shell
                blur-my-shell
                appindicator
              ]
            );
        };
      };
    };

  helix = import ./helix.nix inputs;

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

  linux =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      config = lib.mkIf (config.lyte.shell.enable && (lib.strings.hasSuffix "linux" pkgs.system)) {
        programs.fish = {
          shellAliases = {
            disks = "df -h && lsblk";
            sctl = "sudo systemctl";
            bt = "bluetoothctl";
            pa = "nix run nixpkgs#pulsemixer";
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
            paths = [ ./scripts/linux ];
          })
        ];
      };
    };

  senpai =
    { lib, config, ... }:
    {
      config = lib.mkIf config.lyte.shell.enable {
        programs.senpai = {
          enable = true;
          config = {
            address = "irc+insecure://beefcake.hare-cod.ts.net:6667";
            nickname = "lytedev";
            password-cmd = [
              # TODO: update to use bitwarden-cli?
              "pass"
              "soju"
            ];
          };
        };

        home.file."${config.xdg.configHome}/senpai/senpai.scfg" = {
          enable = true;
          # TODO: update to use bitwarden-cli?
          text = ''
            address irc+insecure://beefcake:6667
            nickname lytedev
            password-cmd pass soju
          '';
        };
      };
    };

  ghostty =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      # options = {
      # };
      config = lib.mkIf config.programs.ghostty.enable {
        home.packages = with pkgs; [
          ghostty
        ];

        home.file."${config.xdg.configHome}/ghostty" = {
          source = conditionalOutOfStoreSymlink config /etc/nix/flake/lib/modules/home/ghostty ./ghostty;
        };
      };
    };

  zellij =
    { config, lib, ... }:
    {
      config = lib.mkIf config.programs.zellij.enable {
        # zellij does not support modern terminal keyboard input:
        # https://github.com/zellij-org/zellij/issues/735
        programs.zellij = {

          # do not start immediately
          enableFishIntegration = false;

          # uses home manager's toKDL generator
          settings = {
            pane_frames = false;
            simplified_ui = true;
            default_mode = "locked";
            mouse_mode = true;
            copy_clipboard = "primary";
            copy_on_select = true;
            mirror_session = false;

            # keybinds = with builtins; let
            #   binder = bind: let
            #     keys = elemAt bind 0;
            #     action = elemAt bind 1;
            #     argKeys = map (k: "\"${k}\"") (lib.lists.flatten [keys]);
            #   in {
            #     name = "bind ${concatStringsSep " " argKeys}";
            #     value = action;
            #   };
            #   layer = binds: (listToAttrs (map binder binds));
            # in {
            #   # _props = {clear-defaults = true;};
            #   normal = {};
            #   locked = layer [
            #     [["Ctrl g"] {SwitchToMode = "Normal";}]
            #     [["Ctrl L"] {NewPane = "Right";}]
            #     [["Ctrl Z"] {NewPane = "Right";}]
            #     [["Ctrl J"] {NewPane = "Down";}]
            #     [["Ctrl h"] {MoveFocus = "Left";}]
            #     [["Ctrl l"] {MoveFocus = "Right";}]
            #     [["Ctrl j"] {MoveFocus = "Down";}]
            #     [["Ctrl k"] {MoveFocus = "Up";}]
            #   ];
            #   resize = layer [
            #     [["Ctrl n"] {SwitchToMode = "Normal";}]
            #     [["h" "Left"] {Resize = "Increase Left";}]
            #     [["j" "Down"] {Resize = "Increase Down";}]
            #     [["k" "Up"] {Resize = "Increase Up";}]
            #     [["l" "Right"] {Resize = "Increase Right";}]
            #     [["H"] {Resize = "Decrease Left";}]
            #     [["J"] {Resize = "Decrease Down";}]
            #     [["K"] {Resize = "Decrease Up";}]
            #     [["L"] {Resize = "Decrease Right";}]
            #     [["=" "+"] {Resize = "Increase";}]
            #     [["-"] {Resize = "Decrease";}]
            #   ];
            #   pane = layer [
            #     [["Ctrl p"] {SwitchToMode = "Normal";}]
            #     [["h" "Left"] {MoveFocus = "Left";}]
            #     [["l" "Right"] {MoveFocus = "Right";}]
            #     [["j" "Down"] {MoveFocus = "Down";}]
            #     [["k" "Up"] {MoveFocus = "Up";}]
            #     [["p"] {SwitchFocus = [];}]
            #     [
            #       ["n"]
            #       {
            #         NewPane = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["d"]
            #       {
            #         NewPane = "Down";
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["r"]
            #       {
            #         NewPane = "Right";
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["x"]
            #       {
            #         CloseFocus = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["f"]
            #       {
            #         ToggleFocusFullscreen = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["z"]
            #       {
            #         TogglePaneFrames = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["w"]
            #       {
            #         ToggleFloatingPanes = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["e"]
            #       {
            #         TogglePaneEmbedOrFloating = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["c"]
            #       {
            #         SwitchToMode = "RenamePane";
            #         PaneNameInput = 0;
            #       }
            #     ]
            #   ];
            #   move = layer [
            #     [["Ctrl h"] {SwitchToMode = "Normal";}]
            #     [["n" "Tab"] {MovePane = [];}]
            #     [["p"] {MovePaneBackwards = [];}]
            #     [["h" "Left"] {MovePane = "Left";}]
            #     [["j" "Down"] {MovePane = "Down";}]
            #     [["k" "Up"] {MovePane = "Up";}]
            #     [["l" "Right"] {MovePane = "Right";}]
            #   ];
            #   tab = layer [
            #     [["Ctrl t"] {SwitchToMode = "Normal";}]
            #     [
            #       ["r"]
            #       {
            #         SwitchToMode = "RenameTab";
            #         TabNameInput = 0;
            #       }
            #     ]
            #     [["h" "Left" "Up" "k"] {GoToPreviousTab = [];}]
            #     [["l" "Right" "Down" "j"] {GoToNextTab = [];}]
            #     [
            #       ["n"]
            #       {
            #         NewTab = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["x"]
            #       {
            #         CloseTab = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["s"]
            #       {
            #         ToggleActiveSyncTab = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["1"]
            #       {
            #         GoToTab = 1;
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["2"]
            #       {
            #         GoToTab = 2;
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["3"]
            #       {
            #         GoToTab = 3;
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["4"]
            #       {
            #         GoToTab = 4;
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["5"]
            #       {
            #         GoToTab = 5;
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["6"]
            #       {
            #         GoToTab = 6;
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["7"]
            #       {
            #         GoToTab = 7;
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["8"]
            #       {
            #         GoToTab = 8;
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["9"]
            #       {
            #         GoToTab = 9;
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [["Tab"] {ToggleTab = [];}]
            #   ];
            #   scroll = layer [
            #     [["Ctrl s"] {SwitchToMode = "Normal";}]
            #     [
            #       ["e"]
            #       {
            #         EditScrollback = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["s"]
            #       {
            #         SwitchToMode = "EnterSearch";
            #         SearchInput = 0;
            #       }
            #     ]
            #     [
            #       ["Ctrl c"]
            #       {
            #         ScrollToBottom = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [["j" "Down"] {ScrollDown = [];}]
            #     [["k" "Up"] {ScrollUp = [];}]
            #     [["Ctrl f" "PageDown" "Right" "l"] {PageScrollDown = [];}]
            #     [["Ctrl b" "PageUp" "Left" "h"] {PageScrollUp = [];}]
            #     [["d"] {HalfPageScrollDown = [];}]
            #     [["u"] {HalfPageScrollUp = [];}]
            #     # uncomment this and adjust key if using copy_on_select=false
            #     # bind "Alt c" { Copy; }
            #   ];
            #   search = layer [
            #     [["Ctrl s"] {SwitchToMode = "Normal";}]
            #     [
            #       ["Ctrl c"]
            #       {
            #         ScrollToBottom = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [["j" "Down"] {ScrollDown = [];}]
            #     [["k" "Up"] {ScrollUp = [];}]
            #     [["Ctrl f" "PageDown" "Right" "l"] {PageScrollDown = [];}]
            #     [["Ctrl b" "PageUp" "Left" "h"] {PageScrollUp = [];}]
            #     [["d"] {HalfPageScrollDown = [];}]
            #     [["u"] {HalfPageScrollUp = [];}]
            #     [["n"] {Search = "down";}]
            #     [["p"] {Search = "up";}]
            #     [["c"] {SearchToggleOption = "CaseSensitivity";}]
            #     [["w"] {SearchToggleOption = "Wrap";}]
            #     [["o"] {SearchToggleOption = "WholeWord";}]
            #   ];
            #   entersearch = layer [
            #     [["Ctrl c" "Esc"] {SwitchToMode = "Scroll";}]
            #     [["Enter"] {SwitchToMode = "Search";}]
            #   ];
            #   renametab = layer [
            #     [["Ctrl c"] {SwitchToMode = "Normal";}]
            #     [
            #       ["Esc"]
            #       {
            #         UndoRenameTab = [];
            #         SwitchToMode = "Tab";
            #       }
            #     ]
            #   ];
            #   renamepane = layer [
            #     [["Ctrl c"] {SwitchToMode = "Normal";}]
            #     [
            #       ["Esc"]
            #       {
            #         UndoRenamePane = [];
            #         SwitchToMode = "Pane";
            #       }
            #     ]
            #   ];
            #   session = layer [
            #     [["Ctrl o"] {SwitchToMode = "Normal";}]
            #     [["Ctrl s"] {SwitchToMode = "Scroll";}]
            #     [["d"] {Detach = [];}]
            #   ];
            #   tmux = layer [
            #     [["["] {SwitchToMode = "Scroll";}]
            #     [
            #       ["Ctrl b"]
            #       {
            #         Write = 2;
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["\\\""]
            #       {
            #         NewPane = "Down";
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["%"]
            #       {
            #         NewPane = "Right";
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["z"]
            #       {
            #         ToggleFocusFullscreen = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["c"]
            #       {
            #         NewTab = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [[","] {SwitchToMode = "RenameTab";}]
            #     [
            #       ["p"]
            #       {
            #         GoToPreviousTab = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["n"]
            #       {
            #         GoToNextTab = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["Left"]
            #       {
            #         MoveFocus = "Left";
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["Right"]
            #       {
            #         MoveFocus = "Right";
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["Down"]
            #       {
            #         MoveFocus = "Down";
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["Up"]
            #       {
            #         MoveFocus = "Up";
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["h"]
            #       {
            #         MoveFocus = "Left";
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["l"]
            #       {
            #         MoveFocus = "Right";
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["j"]
            #       {
            #         MoveFocus = "Down";
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [
            #       ["k"]
            #       {
            #         MoveFocus = "Up";
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #     [["o"] {FocusNextPane = [];}]
            #     [["d"] {Detach = [];}]
            #     [["Space"] {NextSwapLayout = [];}]
            #     [
            #       ["x"]
            #       {
            #         CloseFocus = [];
            #         SwitchToMode = "Normal";
            #       }
            #     ]
            #   ];
            #   "shared_except \"locked\"" = layer [
            #     [["Ctrl g"] {SwitchToMode = "Locked";}]
            #     [["Ctrl q"] {Quit = [];}]
            #     [["Alt n"] {NewPane = [];}]
            #     [["Alt h" "Alt Left"] {MoveFocusOrTab = "Left";}]
            #     [["Alt l" "Alt Right"] {MoveFocusOrTab = "Right";}]
            #     [["Alt j" "Alt Down"] {MoveFocus = "Down";}]
            #     [["Alt k" "Alt Up"] {MoveFocus = "Up";}]
            #     [["Alt ]" "Alt +"] {Resize = "Increase";}]
            #     [["Alt -"] {Resize = "Decrease";}]
            #     [["Alt ["] {PreviousSwapLayout = [];}]
            #     [["Alt ]"] {NextSwapLayout = [];}]
            #   ];
            #   "shared_except \"normal\" \"locked\"" = layer [
            #     [["Enter" "Esc"] {SwitchToMode = "Normal";}]
            #   ];
            #   "shared_except \"pane\" \"locked\"" = layer [
            #     [["Ctrl p"] {SwitchToMode = "Pane";}]
            #   ];
            #   "shared_except \"resize\" \"locked\"" = layer [
            #     [["Ctrl n"] {SwitchToMode = "Resize";}]
            #   ];
            #   "shared_except \"scroll\" \"locked\"" = layer [
            #     [["Ctrl s"] {SwitchToMode = "Scroll";}]
            #   ];
            #   "shared_except \"session\" \"locked\"" = layer [
            #     [["Ctrl o"] {SwitchToMode = "Session";}]
            #   ];
            #   "shared_except \"tab\" \"locked\"" = layer [
            #     [["Ctrl t"] {SwitchToMode = "Tab";}]
            #   ];
            #   "shared_except \"move\" \"locked\"" = layer [
            #     [["Ctrl h"] {SwitchToMode = "Move";}]
            #   ];
            #   "shared_except \"tmux\" \"locked\"" = layer [
            #     [["Ctrl b"] {SwitchToMode = "Tmux";}]
            #   ];
            # };

            # default_layout = "compact";
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
    };

  sshconfig = {
    programs.ssh = {
      enable = true;
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
        "git.hq.bill.com" = {
          user = "git";
        };
        "steam-deck-oled" = {
          user = "deck";
          hostname = "sdo";
        };
        "steam-deck" = {
          user = "deck";
          hostname = "steamdeck";
        };
        work = {
          user = "daniel.flanagan";
        };
      };
      extraConfig = ''
        Include config.d/*
        # pass obscure/keys/ssh-key-ed25519 | tail -n 7
        IdentityFile ~/.ssh/id_ed25519
      '';
    };
  };

  daniel =
    { ... }:
    {
      home = {
        username = "daniel";
        homeDirectory = "/home/daniel/.home";
      };

      accounts.email.accounts.primary = {
        primary = true;
        address = "daniel@lyte.dev";
      };
    };
}
