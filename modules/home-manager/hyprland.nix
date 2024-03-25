{
  outputs,
  colors,
  config,
  lib,
  # font,
  ...
}: {
  imports = with outputs.homeManagerModules; [
    ewwbar
    mako
    swaylock
    # TODO: figure out how to import this for this module _and_ for the sway module?
    # linux-desktop
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
        "eww daemon && eww open bar$EWW_BAR_MON"
        "firefox"
        "kitty --single-instance"
        # "wezterm"
        (lib.concatStringsSep " " [
          "swayidle -w"
          "timeout 300  'notify-send \"Idling in 300 seconds\"' resume 'notify-send \"Idling cancelled.\"'"
          "timeout 480  'notify-send -u critical \"Idling in 120 seconds\"'"
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
          "timeout 600  'swaylock --daemonize'"
          "timeout 600  'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on'"
          "after-resume       'maybe-good-morning'"
          "before-sleep 'swaylock --daemonize'"
        ])
        ''swayidle -w timeout 600 'notify-send "Locking in 30 seconds..."' timeout 630 'swaylock -f' timeout 660 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on && maybe-good-morning' before-sleep 'swaylock -f'"''
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
      ];

      env = [
        "XCURSOR_SIZE,24"
        "EWW_BAR_MON,0"
      ];

      input = {
        kb_layout = "us";
        kb_options = "ctrl:nocaps";
        # kb_variant =
        # kb_model =
        # kb_rules =

        follow_mouse = 2;

        repeat_delay = 200;
        repeat_rate = 60;

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

      general = {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more
        "col.active_border" = "0xff${colors.primary} 0xff${colors.green} 45deg";
        "col.inactive_border" = "0xff${colors.fgdim}";

        gaps_in = 3;
        gaps_out = 6;
        border_size = 2;
        no_cursor_warps = true;
        resize_on_border = true;
        no_focus_fallback = true;

        layout = "dwindle";
      };

      decoration = {
        rounding = 3;
        # blur = "no";
        # blur_size = 3
        # blur_passes = 1
        # blur_new_optimizations = on

        drop_shadow = "yes";
        shadow_range = 4;
        shadow_render_power = 3;
        "col.shadow" = "rgba(1a1a1aee)";

        dim_inactive = false;
      };

      "$mainMod" = "SUPER";
      bind = [
        # See https://wiki.hyprland.org/Configuring/Keywords/ for more
        # "$mainMod, return, exec, wezterm"
        # "$mainMod SHIFT, return, exec, wezterm"
        "$mainMod, return, exec, kitty --single-instance"
        "$mainMod SHIFT, return, exec, kitty"
        "$mainMod, U, exec, firefox"
        "$mainMod, space, exec, wofi --show drun"
        "$mainMod, C, killactive,"
        "$mainMod, M, exit,"
        "$mainMod, E, exec, dolphin"
        "$mainMod, F, togglefloating,"
        "$mainMod SHIFT, F, fullscreen,"
        "$mainMod, R, exec, anyrun"
        "$mainMod, S, pseudo, # dwindle"
        "$mainMod, P, togglesplit, # dwindle"

        # Move focus with mainMod + arrow keys
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        "$mainMod, h, movefocus, l"
        "$mainMod, l, movefocus, r"
        "$mainMod, k, movefocus, u"
        "$mainMod, j, movefocus, d"
        "$mainMod SHIFT, H, swapwindow, l"
        "$mainMod SHIFT, L, swapwindow, r"
        "$mainMod SHIFT, K, swapwindow, u"
        "$mainMod SHIFT, J, swapwindow, d"
        "$mainMod SHIFT, V, exec, pamixer --default-source --toggle-mute"
        "$mainMod, F1, exec, pamixer --default-source --toggle-mute"
        ", XF86AudioMicMute, exec, pamixer --default-source --toggle-mute"
        ", XF86AudioMute, exec, pamixer --toggle-mute"
        ", XF86AudioRaiseVolume, exec, pamixer --increase 5"
        ", XF86AudioLowerVolume, exec, pamixer --decrease 5"
        "CTRL, XF86AudioRaiseVolume, exec, pamixer --increase 1"
        "CTRL, XF86AudioLowerVolume, exec, pamixer --decrease 1"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
        "$mainMod, tab, workspace, previous"
        "ALT, tab, workspace, previous"

        # Switch workspaces with mainMod + [0-9]
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        # Move active window to a workspace with mainMod + SHIFT + [0-9]
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"
        ", XF86MonBrightnessUp, exec, brightnessctl set +10%"
        "SHIFT, XF86MonBrightnessDown, exec, brightnessctl set 1%"
        "SHIFT, XF86MonBrightnessUp, exec, brightnessctl set 100%"
        "CTRL, XF86MonBrightnessDown, exec, brightnessctl set 1%-"
        "CTRL, XF86MonBrightnessUp, exec, brightnessctl set +1%"
        "$mainMod SHIFT, S, exec, clipshot"

        # Scroll through existing workspaces with mainMod + scroll
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
        "CTRL SHIFT $mainMod, L, exec, swaylock"
        "$mainMod CTRL, space, exec, makoctl dismiss"
        "$mainMod SHIFT CTRL, space, exec, makoctl restore"
        "$mainMod SHIFT, space, exec, makoctl invoke"
        "$mainMod, E, exec, thunar"
      ];

      # Move/resize windows with mainMod + LMB/RMB and dragging
      bindm = ["$mainMod, mouse:272, movewindow" "$mainMod, mouse:273, resizewindow"];
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
        # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        pseudotile = yes
        preserve_split = 1
        no_gaps_when_only = true
      }

      master {
        # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
        new_is_master = true
      }

      gestures {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more
        workspace_swipe = on
      }

      # Example per-device config
      # See https://wiki.hyprland.org/Configuring/Keywords/#executing for more
      # device:epic-mouse-v1 {
      #     sensitivity = -0.5
      # }

      # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more
      # windowrulev2 = float,class:^.*(kitty|firefox|org.wezfurlong.wezterm).*$
    '';
  };
}
