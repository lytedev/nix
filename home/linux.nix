{
  config,
  pkgs,
  lib,
  colors,
  font,
  ...
}: {
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 64; # TODO: this doesn't seem to work -- at least in Sway
    # some icons are also missing (hand2?)
  };

  programs.foot = {
    enable = true;
  };

  # programs.eww = {
  #   enable = true;
  # };

  /*
  home.file.".config/eww/eww.yuck" = {
    enable = true;
    text = ''
      (defwidget bar []
        (centerbox :orientation "h"
          (sidestuff)
          (box)
          (music)))

      (defwindow bar
        :monitor 0
        :stacking "fg"
        :exclusive true
        :geometry
        (geometry
          :x "0%"
          :y "0%"
          :width "100%"
          :height "31px"
          :anchor "bottom center")
        (bar))

      (defwidget sidestuff []
        (box :class "sidestuff" :orientation "h" :space-evenly false :halign "start" :spacing 20
          time
          ; TODO: idle inhibitor?
          ; TODO: get these to align properly?
          (box :class "mic" (
            box :class {micMuted == "false" ? "live" : "muted"} {micMuted == "false" ? " " : " "}
            ) {micVolume + "%"}
          )
          (box :class "vol" (
            box :class {muted == "false" ? "live" : "muted"} {muted == "false" ? "󰕾 " : "󰖁 "}
            ) {volume + "%"}
          )
          {" " + round(EWW_CPU["avg"], 0) + "%"}
          {" " + round(EWW_RAM["used_mem_perc"], 0) + "%"}
          {isDesktop == "true" ? "" : " " + brightness + "%"}
          {isDesktop == "true" ? "" : "󱊣 " + EWW_BATTERY["BAT0"]["capacity"] + "%/" + EWW_BATTERY["BAT1"]["capacity"] + "%"}
        ))

      (defwidget music []
        (box :class "music"
             :orientation "h"
             :halign "end"
             :space-evenly false
          {music != "" ? "''${music}" : ""}))

      (deflisten music :initial ""
        "playerctl --follow metadata --format '{{ title }} by {{ artist }}' || true")

      (deflisten volume :initial "0"
        "pamixer --get-volume; pactl subscribe | grep sink --line-buffered | while read i; do pamixer --get-volume; done")

      (deflisten muted :initial "false"
        "pamixer --get-mute; pactl subscribe | grep sink --line-buffered | while read i; do pamixer --get-mute; done")

      (deflisten micVolume :initial "0"
        "pamixer --default-source --get-volume; pactl subscribe | grep source --line-buffered | while read i; do pamixer --default-source --get-volume; done")

      (deflisten micMuted :initial "false"
        "pamixer --default-source --get-mute; pactl subscribe | grep source --line-buffered | while read i; do pamixer --default-source --get-mute; done")

      (defpoll time :interval "1s"
        "date '+%a %b %d %H:%M:%S'")

      (defpoll isDesktop :interval "24h"
        "if [ -d \"$HOME/.config/lytedev-env/host-desktop\" ]; then echo true; else echo false; fi")

      (defpoll brightness :interval "10s"
        "echo $(((100 * $(brightnessctl get)) / $(brightnessctl max)))")
    '';
  };
  */

  programs.fish = {
    shellAliases = {
      sctl = "sudo systemctl";
      sctlu = "systemctl --user";
    };
  };

  services.mako = with colors.withHashPrefix; {
    enable = true;
    borderSize = 1;
    maxVisible = 5;
    defaultTimeout = 15000;
    font = "Symbols Nerd Font ${toString font.size},${font.name} ${toString font.size}";
    # TODO: config

    backgroundColor = bg;
    textColor = text;
    borderColor = primary;
    progressColor = primary;

    extraConfig = ''
      [urgency=high]
      border-color=${urgent}
      [urgency=high]
      background-color=${urgent}
    '';
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

    config = {
      output = {
        "*" = {
          background = "$HOME/.wallpaper fill";
        };
      };

      # TODO: popup_during_fullscreen smart
      focus = {
        wrapping = "no";
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
          command = "systemctl --user restart waybar";
          always = true;
        }
        {
          command = lib.concatStringsSep " " [
            "swayidle -w"
            "timeout 300 'notify-send \"Idling in 300 seconds\"'"
            "resume      'notify-send \"Idling cancelled.\"'"
            "timeout 480 'notify-send \"Idling in 120 seconds\"'"
            "timeout 510 'notify-send \"Idling in 90 seconds\"'"
            "timeout 540 'notify-send \"Idling in 60 seconds!\"'"
            "timeout 570 'notify-send \"Idling in 30 seconds!\"'"
            "timeout 590 'notify-send \"Idling in 10 seconds!\"'"
            "timeout 591 'notify-send \"Idling in 9 seconds!\"'"
            "timeout 592 'notify-send \"Idling in 8 seconds!\"'"
            "timeout 593 'notify-send \"Idling in 7 seconds!\"'"
            "timeout 594 'notify-send \"Idling in 6 seconds!\"'"
            "timeout 595 'notify-send \"Idling in 5 seconds!\"'"
            "timeout 596 'notify-send \"Idling in 4 seconds!\"'"
            "timeout 597 'notify-send \"Idling in 3 seconds!\"'"
            "timeout 598 'notify-send \"Idling in 2 seconds!\"'"
            "timeout 599 'notify-send \"Idling in 1 second!\"'"
            "timeout 600 'swaylock -f'"
            "timeout 600 'swaymsg \"output * dpms off\"'"
            "resume       'swaymsg \"output * dpms on\" & maybe-good-morning &'"
            "before-sleep 'swaylock'"
          ];
        }
        {command = "firefox";}
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
        "${mod}+return" = "exec kitty --single-instance";
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
          border = primary;
          childBorder = primary;
          indicator = primary;
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
          border = bg;
          childBorder = bg;
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

  gtk = {
    enable = true;
    theme = {
      name = "Catppuccin-Mocha-Compact-Sapphire-dark";
      package = pkgs.catppuccin-gtk.override {
        accents = ["sapphire"];
        size = "compact";
        tweaks = ["rimless" "black"];
        variant = "mocha";
      };
    };
  };

  home.packages = [
    (pkgs.buildEnv {
      name = "my-linux-scripts";
      paths = [./scripts/linux];
    })
  ];

  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        "layer" = "top";
        "position" = "bottom";
        "output" = ["eDP-1" "DP-3"];
        "height" = 32;
        "modules-left" = ["clock" "sway/window"];
        "modules-center" = ["sway/workspaces"];
        "modules-right" = [
          "mpris"
          "idle_inhibitor"
          "bluetooth"
          # "wireplumber",
          "pulseaudio"
          # "network",
          "cpu"
          "memory"
          # "temperature",
          "backlight"
          "battery"
          "tray"
        ];
        "bluetooth" = {
          "format" = "<span</span>";
          "format-connected" = "<span></span>";
          "format-connected-battery" = "<span></span>";
          # "format-device-preference" = [ "device1", "device2" ], # preference list deciding the displayed devic;
          "tooltip-format" = "{controller_alias}@{controller_address} ({num_connections} connected)";
          "tooltip-format-connected" = "{controller_alias}@{controller_address} ({num_connections} connected)\n{device_enumerate}";
          "tooltip-format-enumerate-connected" = "{device_alias}@{device_address}";
          "tooltip-format-enumerate-connected-battery" = "{device_alias}@{device_address} (󰁹 {device_battery_percentage}%)";
        };
        # "wireplumber" = ;
        #     "format" = "{volume}% {icon}";
        #     "format-muted" = "";
        #     "on-click" = "helvum;
        # },
        "sway/workspaces" = {
          "disable-scroll" = false;
          "persistent_workspaces" = {
          };
          "all-outputs" = true;
          "format" = "{name}";
        };
        "idle_inhibitor" = {
          "format" = "{icon}";
          "format-icons" = {
            "activated" = "󰈈";
            "deactivated" = "󰈉";
          };
        };
        "tray" = {
          "icon-size" = 24;
          "spacing" = 4;
        };
        "clock" = {
          "interval" = 1;
          "format" = "{:%a %b %d %H:%M:%S}";
        };
        "cpu" = {
          "format" = "{usage} <span></span>";
          "tooltip" = true;
          "interval" = 3;
        };
        "memory" = {
          "format" = "{} 󰍛";
        };
        "temperature" = {
          # "thermal-zone" = 2;
          # "hwmon-path" = "/sys/class/hwmon/hwmon2/temp1_input";
          "critical-threshold" = 80;
          # "format-critical" = "{temperatureC}°C {icon}";
          "format" = "{temperatureC}°C {icon}";
          "format-icons" = ["" "" ""];
        };
        "backlight" = {
          # "device" = "acpi_video1";
          "format" = "{percent}% {icon}";
          "format-icons" = ["" ""];
        };
        "battery" = {
          "states" = {
            # "good" = 95;
            "warning" = 30;
            "critical" = 1;
          };
          "format" = "{capacity}% {icon}";
          "format-charging" = "{capacity}% 󱐋";
          "format-plugged" = "{capacity}% 󰚥";
          "format-alt" = "{time} {icon}";
          "format-good" = ""; # An empty format will hide the modul;
          "format-full" = "󰁹";
          "format-icons" = ["󰂎" "󰁻" "󰁽" "󰁿" "󰂂"];
        };
        "network" = {
          "format-wifi" = "{essid} ({signalStrength}%) ";
          "format-ethernet" = "{ifname}: {ipaddr}/{cidr} ";
          "format-linked" = "{ifname} (No IP) ";
          "format-disconnected" = "Disconnected ⚠";
          "format-alt" = "{ifname}: {ipaddr}/{cidr}";
        };
        "mpris" = {
          "format" = "{title} by {artist}";
        };
        "pulseaudio" = {
          # "scroll-step" = 1, # %, can be a floa;
          "format" = "{volume} {icon} <span>{format_source}</span>";
          #"format" = "{volume}% {icon} {format_source}";
          #"format-bluetooth" = "{volume}% {icon} {format_source}";
          #"format-bluetooth-muted" = " {icon} {format_source}";
          #"format-muted" = " {format_source}";
          "format-muted" = "󰝟  {format_source}";
          "format-source" = "";
          "format-source-muted" = "";
          "format-icons" = {
            "headphones" = "";
            "handsfree" = "󱥋";
            "headset" = "󰋎";
            "phone" = "";
            "portable" = "";
            "car" = "";
            "default" = ["" "" ""];
          };
          # TODO: toggle mute?
          "on-click" = "pavucontrol";
        };
      };
    };
    style = let
      border-width = "0px";
    in
      with colors.withHashPrefix; ''
        * {
        	border-radius: 0;
        	font-family: "${font.name}", "Symbols Nerd Font Mono", sans-serif;
        	font-size: 16px;
        }

        window#waybar {
        	min-height: 32px;
        	background-color: ${bg};
        	color: ${text};
        	border-top: solid ${blue} ${border-width};
        	transition: none;
        }

        window#waybar.hidden {
        	/* opacity: 0.2; */
        }

        window#waybar.empty {
        	/* opacity: 0.2; */
        }

        #workspaces button {
        	padding: 0 0.75em;
        	background-color: transparent;
        	border-top: solid ${primary} ${border-width};
          transition: none;
          color: ${fgdim};
        	background-color: ${bg};
        }

        #workspaces button:hover {
          background: rgba(0, 0, 0, 0.2);
        }

        #workspaces button.active {
          color: ${text};
        	background-color: ${bg};
        }

        #workspaces button.visible {
          color: ${fgdim};
        	background-color: ${bg};
        }

        /* A workspace that is persistent but has windows in it */
        #workspaces button.persistent {
        	color: ${fgdim};
        }

        #workspaces button.focused {
        	color: ${bg};
        	background-color: ${primary};
        }

        #workspaces button.urgent {
        	background-color: ${urgent};
        	color: ${bg};
        	border-top: solid ${urgent} ${border-width};
        }

        #mode {
        	background-color: transparent;
        }

        #clock,
        #battery,
        #cpu,
        #memory,
        #temperature,
        #backlight,
        #network,
        #pulseaudio,
        #custom-media,
        #tray,
        #mode,
        #idle_inhibitor,
        #mpris,
        #window,
        #mpd {
        	margin-top: 1px;
        	padding: 0 0.75em;
        	background-color: inherit;
        	color: ${text};
        }

        #clock {}

        #battery {
        	/* background-color: #ffffff; */
        	/* color: #000000; */
        }

        #battery.charging {
        	/* color: #ffffff; */
        	/* background-color: #26A65B; */
        }

        @keyframes blink {
        	to {
        		background-color: #ffffff;
        		color: #000000;
        	}
        }

        #battery.critical:not(.charging) {
        	background-color: ${red};
        	animation-name: blink;
        	animation-duration: 0.5s;
        	animation-timing-function: linear;
        	animation-iteration-count: infinite;
        	animation-direction: alternate;
        }

        #bluetooth,
        #bluetooth.connected-battery,
        #bluetooth.connected.battery,
        #bluetooth.connected {
        	color: ${text};
        }

        label:focus {
        	/* background-color: #000000; */
        }

        #cpu {
        	/* background-color: #2ecc71; */
        	/* color: #000000; */
        }

        #memory {
        	/* background-color: #9b59b6; */
        }

        #backlight {
        	/* background-color: #90b1b1; */
        }

        #network {
        	/* background-color: #2980b9; */
        }

        #network.disconnected {
        	/* background-color: #f53c3c; */
        }

        #pulseaudio {
        	color: ${red};
        	/* background-color: #f1c40f; */
        	/* color: #000000; */
        }

        #pulseaudio.source-muted {
        	/* background-color: #90b1b1; */
        	color: ${text};
        }

        #custom-media {
        	/* background-color: #66cc99; */
        	/* color: #2a5c45; */
        	/* min-width: 100px; */
        }

        #custom-media.custom-spotify {
        	/* background-color: #66cc99; */
        }

        #custom-media.custom-vlc {
        	/* background-color: #ffa000; */
        }

        #temperature {
        	/* background-color: #f0932b; */
        }

        #temperature.critical {
        	/* background-color: #eb4d4b; */
        }

        #tray {
        	/* background-color: #2980b9; */
        }

        #idle_inhibitor {
        	/* background-color: #2d3436; */
        }

        #idle_inhibitor.activated {
        	/* background-color: #ecf0f1; */
        	/* color: #2d3436; */
        }

        #mpd {
        	/* background-color: #66cc99; */
        	/* color: #2a5c45; */
        }

        #mpd.disconnected {
        	/* background-color: #f53c3c; */
        }

        #mpd.stopped {
        	/* background-color: #90b1b1; */
        }

        #mpd.paused {
        	/* background-color: #51a37a; */
        }
      '';
    systemd = {
      enable = true;
    };
  };

  programs.firefox = {
    # TODO: this should be able to work on macos, no?
    # TODO: enable dark theme by default
    enable = true;

    # TODO: uses nixpkgs.pass so pass otp doesn't work
    package = pkgs.firefox.override {extraNativeMessagingHosts = [pkgs.passff-host];};

    # extensions = with pkgs.nur.repos.rycee.firefox-addons; [
    #   ublock-origin
    # ]; # TODO: would be nice to have _all_ my firefox stuff managed here instead of Firefox Sync maybe?

    profiles = {
      daniel = {
        id = 0;
        settings = {
          "general.smoothScroll" = true;
        };

        extraConfig = ''
          user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
          // user_pref("full-screen-api.ignore-widgets", true);
          user_pref("media.ffmpeg.vaapi.enabled", true);
          user_pref("media.rdd-vpx.enabled", true);
        '';

        userChrome = ''
          #TabsToolbar {
            visibility: collapse;
          }

          #webrtcIndicator {
            display: none;
          }

          #main-window[tabsintitlebar="
          true "]:not([extradragspace="
          true "]) #TabsToolbar>.toolbar-items {
            opacity: 0;
            pointer-events: none;
          }

          #main-window:not([tabsintitlebar="
          true "]) #TabsToolbar {
            visibility: collapse !important;
          }
        '';

        # userContent = ''
        # '';
      };
    };
  };

  programs.swaylock = {
    enable = true;
    settings = {
      color = "ffffffff";
      image = "~/.wallpaper";
      font = font.name;
      show-failed-attempts = true;
      ignore-empty-password = true;

      indicator-radius = "150";
      indicator-thickness = "30";

      inside-color = "11111100";
      inside-clear-color = "11111100";
      inside-ver-color = "11111100";
      inside-wrong-color = "11111100";

      key-hl-color = "a1efe4";
      separator-color = "11111100";

      line-color = "111111cc";
      line-uses-ring = true;

      ring-color = "111111cc";
      ring-clear-color = "f4bf75";
      ring-ver-color = "66d9ef";
      ring-wrong-color = "f92672";
    };
  };
}
