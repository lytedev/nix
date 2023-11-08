{
  config,
  lib,
  outputs,
  ...
}: {
  imports = with outputs.homeManagerModules; [
    melee
    sway
    hyprland
  ];

  wayland.windowManager.hyprland = {
    settings = {
      # See https://wiki.hyprland.org/Configuring/Keywords/ for more
      monitor = [
        "DP-3,3840x2160@120,0x0,1"
      ];
    };
  };

  wayland.windowManager.sway = {
    config = {
      output = {
        "GIGA-BYTE TECHNOLOGY CO., LTD. AORUS FO48U 23070B000307" = {
          mode = "3840x2160@120Hz";
          position = "0,0";
        };

        "Dell Inc. DELL U2720Q D3TM623" = {
          # desktop left vertical monitor
          mode = "3840x2160@60Hz";
          transform = "90";
          scale = "1.5";
          position = "3840,0";
        };
      };

      workspaceOutputAssign =
        (
          map
          (ws: {
            output = "GIGA-BYTE TECHNOLOGY CO., LTD. AORUS FO48U 23070B000307";
            workspace = toString ws;
          })
          (lib.range 1 7)
        )
        ++ (
          map
          (ws: {
            output = "Dell Inc. DELL U2720Q D3TM623";
            workspace = toString ws;
          })
          (lib.range 8 9)
        );
    };
  };

  ssbm = {
    slippi-launcher = {
      isoPath = "${config.home.homeDirectory}/../games/roms/dolphin/melee.iso";
    };
  };
}
