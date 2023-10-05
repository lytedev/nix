{
  programs.eww = {
    enable = true;
  };

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
}
