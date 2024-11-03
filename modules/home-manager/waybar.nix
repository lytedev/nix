{
  pkgs,
  style,
  ...
}: {
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        "layer" = "top";
        "position" = "bottom";
        "output" = ["eDP-1" "DP-3"];
        "height" = 50;
        "modules-left" = [
          "idle_inhibitor"
          "sway/workspaces"
          "sway/window"
        ];
        "modules-center" = [];
        "modules-right" = [
          "privacy"
          "power-profiles-daemon"
          "mpris"
          ## "disk"
          ## TODO: will need a custom module for Disk IO

          ## "wireplumber" # pulseaudio module is more featureful
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "temperature"
          "backlight"
          "battery"

          "bluetooth"
          "tray"
          "clock"
        ];
        "bluetooth" = {
          "format" = "<span></span>";
          "on-click" = "${pkgs.blueman}/bin/blueman-manager";
        };
        "wireplumber" = {
          "format" = "{volume}% {icon}";
          "on-click" = "helvum";
        };
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
          "show-passive-items" = true;
        };
        "clock" = {
          "interval" = 1;
          "format" = "{:%a %b %d\n%H:%M:%S}";
          "justify" = "center";
        };
        "cpu" = {
          "format" = "{usage}%\nCPU";
          "tooltip" = true;
          "interval" = 5;
          "justify" = "center";
        };
        "memory" = {
          "format" = "{}%\nRAM";
          "tooltip" = true;
          "interval" = 5;
          "justify" = "center";
        };
        "temperature" = {
          /*
          "thermal-zone" = 2;
          "hwmon-path" = "/sys/class/hwmon/hwmon2/temp1_input";
          "format-critical" = "{temperatureC}°C {icon}";
          */
          "critical-threshold" = 80;
          "format" = "{temperatureC}\n°C";
          "justify" = "center";
        };
        "backlight" = {
          # "device" = "acpi_video1";
          "format" = "{percent}%\n{icon}";
          "format-icons" = ["" ""];
          "justify" = "center";
        };
        "battery" = {
          "states" = {
            # "good" = 95;
            "warning" = 30;
            "critical" = 1;
          };
          "tooltip-format" = "{timeTo}\n{power} watts\n{health}% health\n{cycles} cycles";
          "format" = "{icon}{capacity}%-\n{time}";
          "format-charging" = "{capacity}%+\n{time}";
          "format-plugged" = "{capacity}%=\n{time}";
          "format-alt" = "{capacity}%";
          "format-good" = ""; # An empty format will hide the module
          "format-time" = "{H}:{m}";
          "justify" = "center";
        };
        "network" = {
          "format-wifi" = "{bandwidthUpBits} up  \n{bandwidthDownBits} down";
          "format-ethernet" = "{bandwidthUpBits} up  \n{bandwidthDownBits} down";
          "format-linked" = "{bandwidthUpBits} up  \n{bandwidthDownBits} down";
          "format-disconnected" = "No Network {icon}";
          "format-alt" = "{bandwidthUpBits} up  \n{bandwidthDownBits} down";
          "interval" = 5;
          "justify" = "right";
        };
        "mpris" = {
          "format" = "{title}\nby {artist}";
          "title-len" = 64;
          "artist-len" = 61;
          "justify" = "center";
        };
        "pulseaudio" = {
          /*
          "scroll-step" = 1, # %, can be a floa;
          "format" = "{volume}% {icon} {format_source}";
          "format-muted" = " {format_source}";
          */
          "format" = "{volume}%\n{format_source}";
          "format-muted" = "MUTE\n{format_source}";
          "format-bluetooth" = "{volume}%\n{format_source}";
          "format-bluetooth-muted" = "MUTE\n{format_source}";
          "format-source" = "MIC ON";
          "format-source-muted" = "MIC OFF";
          # TODO: toggle mute?
          "on-click" = "${pkgs.pavucontrol}/bin/pavucontrol";
          "justify" = "center";
        };
      };
    };
    style = let
      border-width = "0px";
    in
      with style.colors.withHashPrefix; ''
        * {
        	border-radius: 0;
        	font-family: "${style.font.name}", "Symbols Nerd Font Mono", sans-serif;
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
  };
}
