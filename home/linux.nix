{ config, pkgs, ... }: {
  home.pointerCursor = {
    name = "Catppuccin-Mocha-Sapphire-Cursors";
    package = pkgs.catppuccin-cursors.mochaSapphire;
    size = 64; # TODO: this doesn't seem to work -- at least in Sway
  };

  services = {
    mako = {
      enable = true;
    };
  };

  wayland.windowManager.sway = {
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
        wrapping = "yes";
        followMouse = "no";
        mouseWarping = false;
      };

      modifier = "Mod4";

      gaps = {
        smartBorders = "on";
      };

      window = {
        border = 2;
      };

      floating = {
        modifier = config.wayland.windowManager.sway.config.modifier;
        titlebar = false;
      };

      startup = [
        { command = "systemctl --user restart waybar"; always = true; }
        { command = "firefox"; always = true; }
        { command = "kitty --single-instance"; always = true; }
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
      keybindings = let mod = config.wayland.windowManager.sway.config.modifier; in {
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
      assigns = { };
      bars = [ ];
      colors = { };
    };
  };

  gtk = {
    enable = true;
    theme = {
      name = "Catppuccin-Mocha-Compact-Sapphire-dark";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "sapphire" ];
        size = "compact";
        tweaks = [ "rimless" "black" ];
        variant = "mocha";
      };
    };
  };

  home.packages = [
    (pkgs.buildEnv { name = "my-linux-scripts"; paths = [ ../scripts/linux ]; })
  ];

  programs = {
    waybar = {
      enable = true;
      # settings = { };
      # style = ''
      # '';
      systemd = {
        enable = true;
      };
    };

    firefox = {
      # TODO: this should be able to work on macos, no?
      # TODO: enable dark theme by default
      enable = true;

      package = (pkgs.firefox.override { extraNativeMessagingHosts = [ pkgs.passff-host ]; });

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

            #main-window[tabsintitlebar="true"]:not([extradragspace="true"]) #TabsToolbar>.toolbar-items {
              opacity: 0;
              pointer-events: none;
            }

            #main-window:not([tabsintitlebar="true"]) #TabsToolbar {
              visibility: collapse !important;
            }
          '';

          # userContent = ''
          # '';
        };
      };
    };
  };
}
