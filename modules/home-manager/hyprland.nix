{
  # colors,
  # font,
  ...
}: {
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = ''
      # See https://wiki.hyprland.org/Configuring/Monitors/
      monitor=,preferred,auto,auto
      monitor=desc:LG Display 0x0521,preferred,auto,1

      # See https://wiki.hyprland.org/Configuring/Keywords/ for more

      # Execute your favorite apps at launch
      exec-once = firefox & kitty --single-instance & hyprpaper & mako & /usr/lib/polkit-kde-authentication-agent-1
      exec-once = swayidle -w timeout 600 'notify-send "Locking in 30 seconds..."' timeout 630 'swaylock -f' timeout 660 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on && maybe-good-morning' before-sleep 'swaylock -f'
      exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

      env = XCURSOR_SIZE,24

      input {
        kb_layout = us
        kb_options = ctrl:nocaps
        touchpad {
            natural_scroll = yes
        }
        # kb_variant =
        # kb_model =
        # kb_rules =

        follow_mouse = 2

      	repeat_delay = 200
      	repeat_rate = 60

        touchpad {
          natural_scroll = yes
          tap-to-click = true
          middle_button_emulation = true
        }

        force_no_accel = true
        sensitivity = 1 # -1.0 - 1.0, 0 means no modification.
      }

      misc {
        disable_hyprland_logo = true
        disable_splash_rendering = true
      }

      binds {
        allow_workspace_cycles = true
      }

      general {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more

        gaps_in = 3
        gaps_out = 6
        border_size = 1
        no_cursor_warps = true
        resize_on_border = true

        col.active_border = rgba(74c7ecff) 45deg
        col.inactive_border = rgba(59595988)

        layout = dwindle
      }

      decoration {
        # See https://wiki.hyprland.org/Configuring/Variables/ for more

        rounding = 3
        # blur = yes
        # blur_size = 3
        # blur_passes = 1
        # blur_new_optimizations = on

        drop_shadow = yes
        shadow_range = 4
        shadow_render_power = 3
        col.shadow = rgba(1a1a1aee)

        dim_inactive = 0.5
      }

      animations {
        enabled = yes

        # Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more

        bezier = myBezier, 0.05, 0.9, 0.1, 1.05
        bezier=overshot,0.05,0.9,0.1,1.1

        animation = windows, 1, 2, default
        animation = windowsOut, 1, 2, default, popin 80%
        animation = border, 1, 2, default
        animation = borderangle, 1, 2, default
        animation = fade, 1, 2, default
        animation = workspaces, 1, 2, default
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

      # Example windowrule v1
      # windowrule = float, ^(kitty)$
      # Example windowrule v2
      # windowrulev2 = float,class:^(kitty)$,title:^(kitty)$
      # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more

      # See https://wiki.hyprland.org/Configuring/Keywords/ for more
      $mainMod = SUPER

      # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
      bind = $mainMod, return, exec, kitty --single-instance
      bind = $mainMod SHIFT, return, exec, kitty
      bind = $mainMod, U, exec, firefox
      bind = $mainMod, space, exec, wofi --show drun
      bind = $mainMod, C, killactive,
      bind = $mainMod, M, exit,
      bind = $mainMod, E, exec, dolphin
      bind = $mainMod, F, togglefloating,
      bind = $mainMod SHIFT, F, fullscreen,
      bind = $mainMod, R, exec, anyrun
      bind = $mainMod, S, pseudo, # dwindle
      bind = $mainMod, P, togglesplit, # dwindle

      # Move focus with mainMod + arrow keys
      bind = $mainMod, left, movefocus, l
      bind = $mainMod, right, movefocus, r
      bind = $mainMod, up, movefocus, u
      bind = $mainMod, down, movefocus, d
      bind = $mainMod, h, movefocus, l
      bind = $mainMod, l, movefocus, r
      bind = $mainMod, k, movefocus, u
      bind = $mainMod, j, movefocus, d

      bind = $mainMod SHIFT, H, swapwindow, l
      bind = $mainMod SHIFT, L, swapwindow, r
      bind = $mainMod SHIFT, K, swapwindow, u
      bind = $mainMod SHIFT, J, swapwindow, d

      bind = $mainMod SHIFT, V, exec, pamixer --default-source --toggle-mute
      bind = , XF86AudioMicMute, exec, pamixer --default-source --toggle-mute
      bind = , XF86AudioMute, exec, pamixer --toggle-mute
      bind = , XF86AudioRaiseVolume, exec, pamixer --increase 5
      bind = , XF86AudioLowerVolume, exec, pamixer --decrease 5
      bind = CTRL, XF86AudioRaiseVolume, exec, pamixer --increase 1
      bind = CTRL, XF86AudioLowerVolume, exec, pamixer --decrease 1

      bind = , XF86AudioPlay, exec, playerctl play-pause
      bind = , XF86AudioNext, exec, playerctl next
      bind = , XF86AudioPrev, exec, playerctl previous

      bind = $mainMod, tab, workspace, previous

      # Switch workspaces with mainMod + [0-9]
      bind = $mainMod, 1, workspace, 1
      bind = $mainMod, 2, workspace, 2
      bind = $mainMod, 3, workspace, 3
      bind = $mainMod, 4, workspace, 4
      bind = $mainMod, 5, workspace, 5
      bind = $mainMod, 6, workspace, 6
      bind = $mainMod, 7, workspace, 7
      bind = $mainMod, 8, workspace, 8
      bind = $mainMod, 9, workspace, 9
      bind = $mainMod, 0, workspace, 10

      # Move active window to a workspace with mainMod + SHIFT + [0-9]
      bind = $mainMod SHIFT, 1, movetoworkspace, 1
      bind = $mainMod SHIFT, 2, movetoworkspace, 2
      bind = $mainMod SHIFT, 3, movetoworkspace, 3
      bind = $mainMod SHIFT, 4, movetoworkspace, 4
      bind = $mainMod SHIFT, 5, movetoworkspace, 5
      bind = $mainMod SHIFT, 6, movetoworkspace, 6
      bind = $mainMod SHIFT, 7, movetoworkspace, 7
      bind = $mainMod SHIFT, 8, movetoworkspace, 8
      bind = $mainMod SHIFT, 9, movetoworkspace, 9
      bind = $mainMod SHIFT, 0, movetoworkspace, 10

      bind = , XF86MonBrightnessDown, exec, brightnessctl set 10%-
      bind = , XF86MonBrightnessUp, exec, brightnessctl set +10%
      bind = SHIFT, XF86MonBrightnessDown, exec, brightnessctl set 1%
      bind = SHIFT, XF86MonBrightnessUp, exec, brightnessctl set 100%
      bind = CTRL, XF86MonBrightnessDown, exec, brightnessctl set 1%-
      bind = CTRL, XF86MonBrightnessUp, exec, brightnessctl set +1%

      bind = $mainMod SHIFT, S, exec, clipshot

      # Scroll through existing workspaces with mainMod + scroll
      bind = $mainMod, mouse_down, workspace, e+1
      bind = $mainMod, mouse_up, workspace, e-1

      bind = CTRL SHIFT $mainMod, L, exec, swaylock

      # Move/resize windows with mainMod + LMB/RMB and dragging
      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow

      bind = $mainMod CTRL, space, exec, makoctl dismiss
      bind = $mainMod SHIFT CTRL, space, exec, makoctl restore
      bind = $mainMod SHIFT, space, exec, makoctl invoke

      bind = $mainMod, E, exec, thunar
    '';
  };
}
