{
  colors,
  lib,
  ...
}: {
  # zellij does not support modern terminal keyboard input:
  # https://github.com/zellij-org/zellij/issues/735
  programs.zellij = {
    # uses home manager's toKDL generator
    enable = true;
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
        match = with colors.withHashPrefix; {
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
        # tab-bar = {path = "tab-bar";};
        # compact-bar = {path = "compact-bar";};
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
}
