{
  config,
  pkgs,
  ...
}: {
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 64; # TODO: this doesn't seem to work -- at least in Sway
    # some icons are also missing (hand2?)
  };

  services = {
    mako = {
      enable = true;
      borderSize = 1;
      maxVisible = 5;
      defaultTimeout = 15000;
      font = "Symbols Nerd Font 12,IosevkaLyteTerm 12";
      # TODO: config

      backgroundColor = "#1e1e2e";
      textColor = "#cdd6f4";
      borderColor = "#89b4fa";
      progressColor = "#313244";

      extraConfig = ''
        [urgency=high]
        border-color=#fab387
      '';
    };

    swayidle = {
      enable = true;

      events = [
        {
          event = "before-sleep";
          command = "${pkgs.swaylock}/bin/swaylock";
        }
      ];

      timeouts = [
        {
          timeout = 330;
          command = "notify-send \"Idling in 300 seconds\"";
          resumeCommand = "notify-send \"Idling cancelled.\"";
        }
        {
          timeout = 540;
          command = "notify-send \"Idling in 90 seconds\"";
        }
        {
          timeout = 570;
          command = "notify-send \"Idling in 60 seconds\"";
        }
        {
          timeout = 600;
          command = "notify-send \"Idling in 30 seconds...\"";
        }
        {
          timeout = 630;
          command = "swaylock -f";
        }
        {
          timeout = 660;
          command = "swaymsg \"output * dpms off\"";
          resumeCommand = "swaymsg \"output * dpms on\" & maybe-good-morning &";
        }
      ];
    };
  };

  wayland.windowManager.sway = {
    # TODO:
    # + Super+r should rotate the selected group of windows.
    # + Super+Control+{1-9} should control the size of the preselect space.
    # + Super+Shift+b should balance the size of all selected nodes.
    # set $tilers "(wezterm.*|kitty.*|firefox.*|slack.*|Slack.*|thunar.*|Alacritty.*|alacritty.*|Discord.*|discord.*)"
    # for_window [title=".*"] floating enable
    # for_window [app_id=$tilers] floating disable
    #
    # # for_window [title=".*"] opacity $opacity
    #
    # client.focused          #74c7ec #74c7ec #74c7ec #74c7ec #74c7ec
    # client.focused_inactive #100814 #100814 #9b9ebf #100814 #100814
    # client.unfocused        #100814 #100814 #9b9ebf #100814 #100814
    #
    # # TODO: I forget why I needed this - could google it I expect?
    # exec /usr/lib/polkit-kde-authentication-agent-1
    #
    # # prevent all windows from stealing focus
    # no_focus [class=".*"]

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
          command = "systemctl --user restart swayidle";
          always = true;
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
      colors = with config.colorScheme.colors; {
        background = "#1e1e2e";
        focused = {
          background = base03;
          border = base0C;
          childBorder = base0C;
          indicator = base0C;
          text = base05;
        };
        focusedInactive = {
          background = base03;
          border = base0D;
          childBorder = base0D;
          indicator = base0D;
          text = base05;
        };
        placeholder = {
          background = base03;
          border = base0D;
          childBorder = base0D;
          indicator = base0D;
          text = base05;
        };
        unfocused = {
          background = base03;
          border = base03;
          childBorder = base03;
          indicator = base03;
          text = base05;
        };
        urgent = {
          background = base03;
          border = base0F;
          childBorder = base0F;
          indicator = base0F;
          text = base05;
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

  programs = {
    # TODO: hyprland = {
    #   enable = true;
    # };

    waybar = {
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
              "1" = [];
              "2" = [];
              "3" = [];
              "4" = [];
              "5" = [];
              "6" = [];
              "7" = [];
              "8" = [];
              "9" = [];
              # "10" = [;
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
      style = ''
        @define-color base   #1e1e2e;
        @define-color mantle #181825;
        @define-color crust  #11111b;

        @define-color text     #cdd6f4;
        @define-color subtext0 #a6adc8;
        @define-color subtext1 #bac2de;

        @define-color surface0 #313244;
        @define-color surface1 #45475a;
        @define-color surface2 #585b70;

        @define-color overlay0 #6c7086;
        @define-color overlay1 #7f849c;
        @define-color overlay2 #9399b2;

        @define-color blue      #89b4fa;
        @define-color lavender  #b4befe;
        @define-color sapphire  #74c7ec;
        @define-color sky       #89dceb;
        @define-color teal      #94e2d5;
        @define-color green     #a6e3a1;
        @define-color yellow    #f9e2af;
        @define-color peach     #fab387;
        @define-color maroon    #eba0ac;
        @define-color red       #f38ba8;
        @define-color mauve     #cba6f7;
        @define-color pink      #f5c2e7;
        @define-color flamingo  #f2cdcd;
        @define-color rosewater #f5e0dc;

        * {
        	border-radius: 0;
        	font-family: "IosevkaLyteTerm", "Symbols Nerd Font Mono", sans-serif;
        	font-size: 16px;
        }

        window#waybar {
        	min-height: 32px;
        	background-color: @base;
        	color: @crust;
        	border-top: solid @sapphire 1px;
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
        	border-top: solid @sapphire 1px;
          transition: none;
        }

        #workspaces button:hover {
        	/*
        	 * background: rgba(0, 0, 0, 0.2);
        	 * box-shadow: inherit;
        	 */
        }

        #workspaces button.visible {
        	background-color: @base;
        }

        #workspaces button.focused {
        	color: @base;
        	background-color: @sapphire;
        }

        #workspaces button.persistent {
        	color: @surface2;
        }

        #workspaces button.urgent {
        	color: @base;
        	background-color: @red;
        	border-top: solid @red 1px;
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
        	color: @text;
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
        	background-color: @red;
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
        	color: @text;
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
        	color: @red;
        	/* background-color: #f1c40f; */
        	/* color: #000000; */
        }

        #pulseaudio.source-muted {
        	/* background-color: #90b1b1; */
        	color: @text;
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

    firefox = {
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

    swaylock = {
      enable = true;
      settings = {
        color = "ffffffff";
        image = "~/.wallpaper";
        font = "IosevkaLyteTerm";
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
  };
}
