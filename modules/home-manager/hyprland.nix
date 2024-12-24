{
  pkgs,
  style,
  config,
  lib,
  # font,
  ...
}: let
  inherit (style) colors;
in {
  # TODO: Hyprland seems to sometimes use a ton of CPU?

  home.packages = with pkgs; [
    swayosd
  ];

  home.file."${config.xdg.configHome}/hypr/hyprpaper.conf" = {
    enable = true;
    text = ''
      preload = ~/.wallpaper
      wallpaper = ,~/.wallpaper
    '';
  };

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # See https://wiki.hyprland.org/Configuring/Keywords/ for more
      monitor = [
        # See https://wiki.hyprland.org/Configuring/Monitors/
        ",preferred,auto,auto"
      ];

      xwayland = {
        force_zero_scaling = true;
      };

      exec-once = [
        "hyprpaper"
        "mako"
        "swayosd-server"
        "eww daemon"
        "[workspace 1 silent] firefox"
        "[workspace 1 silent] wezterm"
        "xwaylandvideobridge"
        "systemctl --user import-environment QT_QPA_PLATFORMTHEME"
        "hypridle"
      ];

      env = [
        "XCURSOR_SIZE,24"
      ];

      input = {
        kb_layout = "us";
        kb_options = "ctrl:nocaps";

        /*
        kb_variant =
        kb_model =
        kb_rules =
        */

        follow_mouse = 2;

        repeat_delay = 180;
        repeat_rate = 120;

        touchpad = {
          natural_scroll = "yes";
          tap-to-click = true;
          middle_button_emulation = true;
          disable_while_typing = false;
        };
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      binds = {
        allow_workspace_cycles = true;
      };

      cursor = {
        no_warps = true;
      };

      general = {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more
        "col.active_border" = "0xff${colors.primary} 0xff${colors.green} 45deg";
        "col.inactive_border" = "0xff${colors.fgdim}";

        gaps_in = 3;
        gaps_out = 6;
        border_size = 2;
        resize_on_border = true;
        no_focus_fallback = true;

        layout = "dwindle";
      };

      decoration = {
        rounding = 5;

        /*
        blur = "no";
        blur_size = 3
        blur_passes = 1
        blur_new_optimizations = on
        */

        shadow = {
          enabled = true;
          color = "rgba(1a1a1aee)";
          range = 4;
          render_power = 3;
        };

        dim_inactive = false;
      };

      "$mod" = "SUPER";
      bind = [
        # See https://wiki.hyprland.org/Configuring/Keywords/ for more
        /*
        "$mod, return, exec, wezterm"
        "$mod SHIFT, return, exec, wezterm"
        */
        "$mod, return, exec, wezterm"
        "$mod SHIFT, return, exec, kitty"
        "$mod, U, exec, firefox"
        "$mod, space, exec, tofi-run | xargs hyprctl dispatch exec --"
        "$mod, C, killactive,"
        "$mod SHIFT, E, exit,"
        "$mod, E, exec, dolphin"
        "$mod, F, togglefloating,"
        "$mod SHIFT, F, fullscreen,"
        "$mod, R, exec, anyrun"
        "$mod, S, pseudo, # dwindle"
        "$mod, P, togglesplit, # dwindle"

        # Move focus with mod + arrow keys
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        "$mod, h, movefocus, l"
        "$mod, l, movefocus, r"
        "$mod, k, movefocus, u"
        "$mod, j, movefocus, d"
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, J, movewindow, d"

        "$mod SHIFT, V, exec, swayosd-client --input-volume mute-toggle"
        ", XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle"
        ", XF86AudioMute, exec, swayosd-client --output-volume mute-toggle"
        ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise"
        ", XF86AudioLowerVolume, exec, swayosd-client --output-volume lower"

        ", XF86MonBrightnessUp, exec, swayosd-client --brightness raise"
        ", XF86MonBrightnessDown, exec, swayosd-client --brightness lower"

        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"

        "$mod, tab, workspace, previous"
        "ALT, tab, workspace, previous"

        # Switch workspaces with mod + [0-9]
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Move active window to a workspace with mod + SHIFT + [0-9]
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"
        "$mod SHIFT, S, exec, clipshot"

        # Scroll through existing workspaces with mod + scroll
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
        "CTRL SHIFT $mod, L, exec, hyprlock"
        "$mod CTRL, space, exec, makoctl dismiss"
        "$mod SHIFT CTRL, space, exec, makoctl restore"
        "$mod SHIFT, space, exec, makoctl invoke default"
        "$mod, E, exec, thunar"
      ];

      # Move/resize windows with mod + LMB/RMB and dragging
      bindm = ["$mod, mouse:272, movewindow" "$mod, mouse:273, resizewindow"];
    };

    extraConfig = ''
      animations {
        enabled = yes

        # Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more

        bezier = myBezier, 0.05, 0.9, 0.1, 1.05
        bezier = overshot, 0.05, 0.9, 0.1, 1.1

        #           name,       onoff, speed, curve,   style
        animation = global,     1,     2,     default
        animation = fadeDim,    1,     2,     default
        animation = windowsOut, 1,     2,     default, popin 80%
      }

      dwindle {
        # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
        # master switch for pseudotiling. Enabling is bound to mod + P in the keybinds section below
        pseudotile = yes
        preserve_split = 1
        # no_gaps_when_only = true
      }

      master {
        # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
        # new_is_master = true
      }

      gestures {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more
        workspace_swipe = on
      }

      ## Example per-device config
      ## See https://wiki.hyprland.org/Configuring/Keywords/#executing for more
      ## device:epic-mouse-v1 {
      ##     sensitivity = -0.5
      ## }

      ## See https://wiki.hyprland.org/Configuring/Window-Rules/ for more
      windowrulev2 = idleinhibit,class:^.*([Ss]lippi).*$
      windowrulev2 = float,class:^.*$
      windowrulev2 = tile,class:^.*([Kk]itty|[Ff]irefox|[Ww]ezterm|[Dd]iscord|[Ss]potify|[Ss]lack).*$
      windowrulev2 = opacity 1.0 0.95,class:^.*$
      windowrulev2 = center 1,floating:1

      windowrulev2 = opacity 0.0 override, class:^(xwaylandvideobridge)$
      windowrulev2 = noanim, class:^(xwaylandvideobridge)$
      windowrulev2 = noinitialfocus, class:^(xwaylandvideobridge)$
      windowrulev2 = maxsize 1 1, class:^(xwaylandvideobridge)$
      windowrulev2 = noblur, class:^(xwaylandvideobridge)$
      windowrulev2 = nofocus, class:^(xwaylandvideobridge)$
    '';
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      # docs: https://wiki.hyprland.org/Hypr-Ecosystem/hyprlock

      general = {
        grace = 0;
        no_face_out = true;
      };

      input-field = [
        {
          monitor = "";
          fade_on_empty = false;
          placeholder_text = "Locked";
          rounding = 5;
          font_size = 20;
          font_color = "rgba(255, 255, 255, 1.0)";
          inner_color = "rgba(31, 31, 47, 0.95)";
          outer_color = "0xff74c7ec 0xff74c7ec 45deg";
          outline_thickness = 3;
          position = "0, -200";

          dots_size = 0.1;
          size = "300 75";
          font_family = "IosevkaLyteTerm";

          shadow_passes = 3;
          shadow_size = 8;
          shadow_color = "rgba(0, 0, 0, 1.0)";
          shadow_boost = 0.8;
        }
      ];

      background = [
        {
          path = "~/.wallpaper";
          blur_passes = 2;
        }
      ];

      label = [
        {
          monitor = "";
          font_size = 64;

          halign = "center";
          valign = "center";
          text_align = "center";

          # rotate = 10;
          position = "0, 250";
          font_family = "IosevkaLyteTerm";
          text = ''Locked for <span foreground="##74c7ec">$USER</span>'';

          shadow_passes = 1;
          shadow_size = 8;
          shadow_color = "rgba(0, 0, 0, 1.0)";
          shadow_boost = 0.5;
        }

        {
          monitor = "";
          font_size = 32;

          halign = "center";
          valign = "center";
          text_align = "center";
          color = "rgba(255, 255, 255, 0.5)";

          position = "0 100";
          font_family = "IosevkaLyteTerm";
          text = "cmd[update:1000] date '+%a %b %d %H:%M:%S'";

          shadow_passes = 3;
          shadow_size = 1;
          shadow_color = "rgba(0, 0, 0, 1.0)";
          shadow_boost = 1.0;
        }

        {
          monitor = "";
          font_size = 200;

          halign = "center";
          valign = "center";
          text_align = "center";
          color = "rgba(220, 240, 255, 0.8)";
          position = "0 500";
          font_family = "NerdFontSymbolsOnly";
          text = "󰍁";

          shadow_passes = 3;
          shadow_size = 1;
          shadow_color = "rgba(0, 0, 0, 1.0)";
          shadow_boost = 1.0;
        }
      ];
    };
  };

  services.hypridle = let
    secondsPerMinute = 60;
    lockSeconds = 10 * secondsPerMinute;
  in {
    enable = true;
    settings = {
      general = {
        after_sleep_cmd = "hyprctl dispatch dpms on";
        before_sleep_cmd = "loginctl lock-session";
        ignore_dbus_inhibit = false;
        lock_cmd = "pidof hyprlock || hyprlock";
      };

      listener = [
        {
          timeout = lockSeconds - 300;
          on-timeout = ''notify-send "Auto-locking in 5 minutes"'';
          on-resume = ''notify-send "Auto-locking cancelled"'';
        }
        {
          timeout = lockSeconds - 180;
          on-timeout = ''notify-send "Auto-locking in 3 minutes"'';
        }
        {
          timeout = lockSeconds - 120;
          on-timeout = ''notify-send "Auto-locking in 2 minutes"'';
        }
        {
          timeout = lockSeconds - 60;
          on-timeout = ''notify-send "Auto-locking in 1 minute"'';
        }
        {
          timeout = lockSeconds - 30;
          on-timeout = ''notify-send "Auto-locking in 30 seconds"'';
        }
        {
          timeout = lockSeconds - 10;
          on-timeout = ''notify-send -u critical "Auto-locking in 10 seconds"'';
        }
        {
          timeout = lockSeconds;
          on-timeout = ''loginctl lock-session'';
        }
        {
          timeout = lockSeconds + 5;
          on-timeout = ''hyprctl dispatch dpms off'';
          on-resume = ''hyprctl dispatch dpms on'';
        }
      ];
    };
  };
}
