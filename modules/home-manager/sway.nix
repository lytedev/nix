{
  colors,
  outputs,
  lib,
  config,
  # font,
  ...
}: {
  imports = with outputs.homeManagerModules; [
    waybar
    mako
    swaylock
    linux-desktop
  ];

  programs.wofi = {
    enable = true;
    settings = {
      width = "640";
      height = "360";
    };
    style = ''
      * {
        border-radius: 0;
      }

      window {
        margin: 0px;
        padding: 8px;
      }

      #outer-box {
        margin: 8px;
      }

      #outer-box, #inner-box {
        margin-top: 8px;
      }
    '';
  };

  programs.foot = {
    enable = true;
  };

  wayland.windowManager.sway = {
    /*
       TODO:
    + Super+r should rotate the selected group of windows.
    + Super+Control+{1-9} should control the size of the preselect space.
    + Super+Shift+b should balance the size of all selected nodes.
    set $tilers "(wezterm.*|kitty.*|firefox.*|slack.*|Slack.*|thunar.*|Alacritty.*|alacritty.*|Discord.*|discord.*)"
    for_window [title=".*"] floating enable
    for_window [app_id=$tilers] floating disable

    # for_window [title=".*"] opacity $opacity

    # TODO: I forget why I needed this - could google it I expect?
    exec /usr/lib/polkit-kde-authentication-agent-1

    # prevent all windows from stealing focus
    no_focus [class=".*"]
    */

    enable = true;

    systemd = {
      enable = true;
    };

    # TODO: stuff is opening on workspace 10 (0?)
    extraConfig = ''
      exec --no-startup-id {
        swaymsg "workspace 1"
      }

      set $tilers "(wezterm.*|kitty.*|firefox.*|slack.*|Slack.*|thunar.*|Alacritty.*|alacritty.*|Discord.*|discord.*)"
      for_window [title=".*"] floating enable
      for_window [app_id=$tilers] floating disable
    '';
    config = {
      defaultWorkspace = "1";

      workspaceOutputAssign = [
        /*
        {
          output = "eDP";
          workspace = "1";
        */
      ];

      output = {
        "*" = {
          background = "$HOME/.wallpaper fill";
        };
      };

      # TODO: popup_during_fullscreen smart
      focus = {
        wrapping = "no"; # maybe workspace?
        followMouse = "no";
        mouseWarping = false;
      };

      modifier = "Mod4";

      gaps = {
        smartBorders = "on";
      };

      window = {
        border = 2;
        titlebar = false;
      };

      floating = {
        modifier = config.wayland.windowManager.sway.config.modifier;
        titlebar = false;
      };

      startup = [
        {
          command = "waybar";
        }
        {
          command = lib.concatStringsSep " " [
            "swayidle -w"
            "before-sleep 'swaylock'"
            "timeout 300 'notify-send \"Idling in 5 minutes\"' resume 'notify-send \"Idling cancelled.\"'"
            "timeout 480  'notify-send -u critical \"Idling in 2 minutes\"'"
            "timeout 510  'notify-send -u critical \"Idling in 90 seconds\"'"
            "timeout 540  'notify-send -u critical \"Idling in 60 seconds!\"'"
            "timeout 570  'notify-send -u critical \"Idling in 30 seconds!\"'"
            "timeout 590  'notify-send -u critical \"Idling in 10 seconds!\"'"
            "timeout 591  'notify-send -u critical \"Idling in 9 seconds!\"'"
            "timeout 592  'notify-send -u critical \"Idling in 8 seconds!\"'"
            "timeout 593  'notify-send -u critical \"Idling in 7 seconds!\"'"
            "timeout 594  'notify-send -u critical \"Idling in 6 seconds!\"'"
            "timeout 595  'notify-send -u critical \"Idling in 5 seconds!\"'"
            "timeout 596  'notify-send -u critical \"Idling in 4 seconds!\"'"
            "timeout 597  'notify-send -u critical \"Idling in 3 seconds!\"'"
            "timeout 598  'notify-send -u critical \"Idling in 2 seconds!\"'"
            "timeout 599  'notify-send -u critical \"Idling in 1 second!\"'"
            "timeout 600  'swaylock -f'"
            "timeout 600  'swaymsg \"output * dpms off\"' resume 'swaymsg \"output * dpms on\" & maybe-good-morning &'"
          ];
        }
        # {command = "firefox";}
        # {command = "wezterm";}
        {command = "kitty --single-instance";}
      ];

      modes = {
        resize = {
          "h" = "resize shrink width 10 px or 10 ppt";
          "j" = "resize grow height 10 px or 10 ppt";
          "k" = "resize shrink height 10 px or 10 ppt";
          "l" = "resize grow width 10 px or 10 ppt";

          "left" = "resize shrink width 10 px or 10 ppt";
          "down" = "resize grow height 10 px or 10 ppt";
          "up" = "resize shrink height 10 px or 10 ppt";
          "right" = "resize grow width 10 px or 10 ppt";

          "return" = ''mode "default"'';
          "escape" = ''mode "default"'';
        };
      };

      input = {
        "type:keyboard" = {
          xkb_options = "ctrl:nocaps";
          repeat_delay = "200";
          repeat_rate = "60";
        };

        "type:pointer" = {
          accel_profile = "flat";
          pointer_accel = "0";
        };

        "type:touchpad" = {
          dwt = "disabled";
          tap = "enabled";
          natural_scroll = "enabled";
          middle_emulation = "enabled";
          # pointer_accel
        };
      };
      keybindings = let
        mod = config.wayland.windowManager.sway.config.modifier;
      in {
        # bindsym $mod+shift+space exec wofi --show drun
        "${mod}+control+space" = "exec makoctl dismiss";
        "${mod}+shift+space" = "exec makoctl invoke";
        # "${mod}+return" = "exec kitty --single-instance";
        "${mod}+return" = "exec kitty";
        "${mod}+shift+return" = "exec floating-term";
        "${mod}+shift+alt+return" = "exec kitty";
        "${mod}+c" = "kill";
        "${mod}+shift+c" = "kill # TODO: kill -9?";
        "${mod}+space" = "exec wofi --show drun";
        "${mod}+shift+s" = "exec clipshot";
        "${mod}+e" = "exec thunar";
        "${mod}+shift+r" = "reload";
        "${mod}+control+Escape" = "exit";
        "${mod}+shift+e" = "exit";
        "${mod}+shift+p" = "exec pass-chooser";
        "${mod}+control+j" = "split v";
        "${mod}+control+l" = "split h";
        "${mod}+control+f" = "focus mode_toggle";

        "${mod}+h" = "focus left";
        "${mod}+j" = "focus down";
        "${mod}+k" = "focus up";
        "${mod}+l" = "focus right";

        "${mod}+left" = "focus left";
        "${mod}+down" = "focus down";
        "${mod}+up" = "focus up";
        "${mod}+right" = "focus right";

        "${mod}+shift+h" = "move left";
        "${mod}+shift+j" = "move down";
        "${mod}+shift+k" = "move up";
        "${mod}+shift+l" = "move right";

        "${mod}+shift+left" = "move left";
        "${mod}+shift+down" = "move down";
        "${mod}+shift+up" = "move up";
        "${mod}+shift+right" = "move right";

        "${mod}+1" = "workspace 1";
        "${mod}+2" = "workspace 2";
        "${mod}+3" = "workspace 3";
        "${mod}+4" = "workspace 4";
        "${mod}+5" = "workspace 5";
        "${mod}+6" = "workspace 6";
        "${mod}+7" = "workspace 7";
        "${mod}+8" = "workspace 8";
        "${mod}+9" = "workspace 9";
        "${mod}+0" = "workspace 10";

        "${mod}+shift+1" = "move container to workspace 1";
        "${mod}+shift+2" = "move container to workspace 2";
        "${mod}+shift+3" = "move container to workspace 3";
        "${mod}+shift+4" = "move container to workspace 4";
        "${mod}+shift+5" = "move container to workspace 5";
        "${mod}+shift+6" = "move container to workspace 6";
        "${mod}+shift+7" = "move container to workspace 7";
        "${mod}+shift+8" = "move container to workspace 8";
        "${mod}+shift+9" = "move container to workspace 9";
        "${mod}+shift+0" = "move container to workspace 10";

        "${mod}+b" = "splith";
        "${mod}+v" = "splitv";

        "${mod}+shift+f" = "fullscreen toggle";
        "${mod}+f" = "floating toggle";
        "${mod}+s" = "floating disable";
        "${mod}+alt+f" = "focus mode_toggle";
        "${mod}+p" = "focus parent";
        "${mod}+period" = "focus child";
        "${mod}+comma" = "focus child";

        "${mod}+tab" = "workspace back_and_forth";
        "alt+tab" = "workspace back_and_forth";

        "${mod}+minus" = "gaps inner current minus 5";
        "${mod}+plus" = "gaps inner current plus 5";
        "${mod}+control+alt+h" = "gaps horizontal current minus 5";
        "${mod}+control+alt+l" = "gaps horizontal current plus 5";
        "${mod}+control+alt+j" = "gaps vertical current minus 5";
        "${mod}+control+alt+k" = "gaps vertical current plus 5";

        # TODO: this should also reset the horizontal and vertical gaps?
        "${mod}+control+equal" = "gaps inner current set 0";

        "XF86AudioRaiseVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ +5%";
        "XF86AudioLowerVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ -5%";
        "control+XF86AudioRaiseVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ +1%";
        "control+XF86AudioLowerVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ -1%";
        "XF86AudioMute" = "exec pactl set-sink-mute @DEFAULT_SINK@ toggle";
        "${mod}+F1" = "exec pactl set-sink-mute @DEFAULT_SINK@ toggle";
        "XF86AudioMicMute" = "exec pactl set-source-mute @DEFAULT_SOURCE@ toggle";
        "XF86MonBrightnessDown" = "exec brightnessctl set 10%-";
        "XF86MonBrightnessUp" = "exec brightnessctl set +10%";
        "shift+XF86MonBrightnessDown" = "exec brightnessctl set 1%";
        "shift+XF86MonBrightnessUp" = "exec brightnessctl set 100%";
        "control+XF86MonBrightnessDown" = "exec brightnessctl set 1%-";
        "control+XF86MonBrightnessUp" = "exec brightnessctl set +1%";
        "XF86AudioPlay" = "exec playerctl play-pause";
        "XF86AudioNext" = "exec playerctl next";
        "XF86AudioPrev" = "exec playerctl previous";
        "${mod}+shift+v" = "exec pactl set-source-mute @DEFAULT_SOURCE@ toggle";

        "${mod}+control+shift+l" = "exec swaylock";

        "${mod}+shift+alt+f" = "for_window [class=$tilers] floating toggle";
      };
      assigns = {};
      bars = [];
      colors = with colors; {
        background = bg;
        focused = {
          background = bg;
          border = primary;
          childBorder = primary;
          indicator = primary;
          text = bg;
        };
        focusedInactive = {
          background = bg;
          border = bg3;
          childBorder = bg3;
          indicator = bg;
          text = bg;
        };
        placeholder = {
          background = bg;
          border = primary;
          childBorder = primary;
          indicator = primary;
          text = text;
        };
        unfocused = {
          background = bg;
          border = bg3;
          childBorder = bg3;
          indicator = bg;
          text = text;
        };
        urgent = {
          background = urgent;
          border = urgent;
          childBorder = urgent;
          indicator = urgent;
          text = bg;
        };
      };
    };
  };

  # this doesn't work due to weird quoting bugs AFAICT
  /*
  services.swayidle = let
    bins = rec {
      swaylock = builtins.trace "${pkgs.swaylock}/bin/swaylock" "${pkgs.swaylock}/bin/swaylock";
      swaymsg = "${pkgs.sway}/bin/swaymsg";
      notify-send = "${swaymsg} exec -- ${pkgs.libnotify}/bin/notify-send";
    };
  in (with bins; {
    enable = true;

    events = [
      {
        event = "before-sleep";
        command = swaylock;
      }
    ];

    timeouts = [
      {
        timeout = 5;
        command = "${notify-send} \\\"Idling in 300 seconds\\\"";
        resumeCommand = "${notify-send} \\\"Idling cancelled.\\\"";
      }
      {
        # timeout = 540;
        timeout = 6;
        command = "${notify-send} 'Idling in 90 seconds'";
      }
      {
        # timeout = 570;
        timeout = 7;
        command = "${notify-send} 'Idling in 60 seconds'";
      }
      {
        # timeout = 600;
        timeout = 8;
        command = "${notify-send} 'Idling in 30 seconds...'";
      }
      {
        # timeout = 630;
        timeout = 9;
        command = "${swaylock} -f";
      }
      {
        # timeout = 660;
        timeout = 10;
        command = "${swaymsg} 'output * dpms off'";
        resumeCommand = "${swaymsg} 'output * dpms on' & ${swaymsg} exec -- maybe-good-morning &";
      }
    ];
  });
  */
}
