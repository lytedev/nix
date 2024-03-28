{
  pkgs,
  colors,
  config,
  lib,
  # font,
  ...
}: {
  imports = [
    ./ewwbar.nix
    ./mako.nix
    ./swaylock.nix
    # TODO: figure out how to import this for this module _and_ for the sway module?
    ./linux-desktop.nix
  ];

  home.packages = with pkgs; [
    # TODO: integrate osd
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
        "eww daemon && eww open bar$EWW_BAR_MON"
        "firefox"
        "wezterm"
        "xwaylandvideobridge"
        "dbus-update-activation-environment --systemd --all"
        "systemctl --user import-environment QT_QPA_PLATFORMTHEME"
        # "wezterm"
        # NOTE: maybe check out hypridle?
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

      "$mod" = "SUPER";
      bind = [
        # See https://wiki.hyprland.org/Configuring/Keywords/ for more
        # "$mod, return, exec, wezterm"
        # "$mod SHIFT, return, exec, wezterm"
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
        "$mod SHIFT, H, swapwindow, l"
        "$mod SHIFT, L, swapwindow, r"
        "$mod SHIFT, K, swapwindow, u"
        "$mod SHIFT, J, swapwindow, d"

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
        "CTRL SHIFT $mod, L, exec, swaylock"
        "$mod CTRL, space, exec, makoctl dismiss"
        "$mod SHIFT CTRL, space, exec, makoctl restore"
        "$mod SHIFT, space, exec, makoctl invoke"
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
      windowrulev2 = idleinhibit,class:^.*([Ss]lippi).*$
      windowrulev2 = float,class:^.*([Kk]itty|[Ff]irefox|[Ww]ezterm|[Dd]iscord|[Ss]potify|[Ss]lack).*$
      windowrulev2 = opacity 1.0 0.9,floating:1

      windowrulev2 = opacity 0.0 override 0.0 override,class:^(xwaylandvideobridge)$
      windowrulev2 = noanim,class:^(xwaylandvideobridge)$
      windowrulev2 = noinitialfocus,class:^(xwaylandvideobridge)$
      windowrulev2 = maxsize 1 1,class:^(xwaylandvideobridge)$
      windowrulev2 = noblur,class:^(xwaylandvideobridge)$
    '';
  };
}
