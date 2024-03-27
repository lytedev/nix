{
  config,
  pkgs,
  inputs,
  colors,
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

  # NOTE: Currently, helix crashes when editing markdown in certain scenarios,
  # presumably due to an old markdown treesitter grammar
  # https://github.com/helix-editor/helix/issues/9011

  programs.helix = {
    enable = true;
    package = inputs.helix.packages.${system}.helix;
    languages = {
      language-server = {
        lexical = {
          command = "lexical";
          args = ["start"];
        };

        # next-ls = {
        #   command = "next-ls";
        #   args = ["--stdout"];
        # };

        # deno = {
        #   command = "deno";
        #   args = ["lsp"];
        #   config = {
        #     enable = true;
        #     lint = true;
        #     unstable = true;
        #   };
        # };
      };

      language = [
        # {
        #   name = "heex";
        #   scope = "source.heex";
        #   injection-regex = "heex";
        #   language-servers = ["lexical"]; # "lexical" "next-ls" ?
        #   auto-format = true;
        #   file-types = ["heex"];
        #   roots = ["mix.exs" "mix.lock"];
        #   indent = {
        #     tab-width = 2;
        #     unit = "  ";
        #   };
        # }
        # {
        #   name = "elixir";
        #   language-servers = ["lexical"]; # "lexical" "next-ls" ?
        #   auto-format = true;
        # }
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

        # {
        #   name = "javascript";
        #   language-id = "javascript";
        #   grammar = "javascript";
        #   scope = "source.js";
        #   injection-regex = "^(js|javascript)$";
        #   file-types = ["js" "mjs"];
        #   shebangs = ["deno"];
        #   language-servers = ["deno"];
        #   roots = ["deno.jsonc" "deno.json"];
        #   formatter = {
        #     command = "deno";
        #     args = ["fmt"];
        #   };
        #   auto-format = true;
        #   comment-token = "//";
        #   indent = {
        #     tab-width = 2;
        #     unit = "\t";
        #   };
        # }

        # {
        #   name = "typescript";
        #   language-id = "typescript";
        #   grammar = "typescript";
        #   scope = "source.ts";
        #   injection-regex = "^(ts|typescript)$";
        #   file-types = ["ts"];
        #   shebangs = ["deno"];
        #   language-servers = ["deno"];
        #   roots = ["deno.jsonc" "deno.json"];
        #   formatter = {
        #     command = "deno";
        #     args = ["fmt"];
        #   };
        #   auto-format = true;
        #   comment-token = "//";
        #   indent = {
        #     tab-width = 2;
        #     unit = "\t";
        #   };
        # }

        # {
        #   name = "jsonc";
        #   language-id = "json";
        #   grammar = "jsonc";
        #   scope = "source.jsonc";
        #   injection-regex = "^(jsonc)$";
        #   roots = ["deno.jsonc" "deno.json"];
        #   file-types = ["jsonc"];
        #   language-servers = ["deno"];
        #   indent = {
        #     tab-width = 2;
        #     unit = "  ";
        #   };
        #   auto-format = true;
        # }
      ];
    };

    settings = {
      theme = "custom";

      editor = {
        soft-wrap.enable = true;
        auto-pairs = false;
        # auto-save = false;
        # completion-trigger-len = 1;
        # color-modes = false;
        bufferline = "multiple";
        # scrolloff = 8;
        rulers = [81 121];
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
            # "selections"
            # "primary-selection-length"
            # "position"
            # "position-percentage"
            "spinner"
            "diagnostics"
            "workspace-diagnostics"
          ];
        };
        #   center = ["file-name"];
        # right = ["version-control" "total-line-numbers" "file-encoding"];
        # };
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

    themes = with colors.withHashPrefix; {
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

        # "ui.cursorline.primary" = { bg = "default" }
        # "ui.cursorline.secondary" = { bg = "default" }
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
}
