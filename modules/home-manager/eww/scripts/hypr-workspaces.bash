#!/usr/bin/env bash

# TODO: we're mixing bash arrays and not-arrays - get it together

#define icons for workspaces 1-9
ic=(1 2 3 4 5 6 7 8 9)

occ() { export o"$1"="occupied"; }
unocc() { unset -v o"$1"; }

active() { export a"$1"="active"; }
unactive() { unset -v a"$1"; }

focus() { export f"$1"="focused"; }
unfocus() { unset -v f"$1"; }

workspaces() {
  for num in 1 2 3 4 5 6 7 8 9; do
    unfocus $num
    unactive $num
    unocc $num
  done

  # TODO: avoid recomputing these each time and actually listen to the events?
  mons_json=$(hyprctl monitors -j)
  for num in $(hyprctl workspaces -j | jq -r '.[] | select(.windows > 0) | .id'); do 
    occ "$num"
  done
 
  for num in $(echo "$mons_json" | jq -r '.[].activeWorkspace.id'); do 
    active "$num"
  done

  for num in $(echo "$mons_json" | jq -r '.[] | select(.focused) | .activeWorkspace.id'); do 
    focus "$num"
  done

  # TODO: would be nice to have monitors' workspaces show up in left-to-right
  # order as laid out in physical/pixel space
  # this would make glancing at the workspace indicator more intuitive
  # TODO: might be nice to exclude certain windows as counting towards "occupation" such as xwaylandvideobridge or w/e
  # NOTE: maybe I can group workspaces by their monitor with some mechanism for "unassigned" workspace to show up by a "primary" monitor

  # render eww widget
  echo "(eventbox :onscroll \"echo {} | sed -e 's/up/-1/g' -e 's/down/+1/g' | xargs hyprctl dispatch workspace\" \
    (box :class \"workspaces\" :orientation \"h\" :spacing 0 :space-evenly \"true\" \
      (button :onclick \"hyprctl dispatch workspace 1\" :onrightclick \"hyprctl dispatch workspace 1\" :class \"workspace $a1 $o1 $f1\" \"${ic[0]}\") \
      (button :onclick \"hyprctl dispatch workspace 2\" :onrightclick \"hyprctl dispatch workspace 2\" :class \"workspace $a2 $o2 $f2\" \"${ic[1]}\") \
      (button :onclick \"hyprctl dispatch workspace 3\" :onrightclick \"hyprctl dispatch workspace 3\" :class \"workspace $a3 $o3 $f3\" \"${ic[2]}\") \
      (button :onclick \"hyprctl dispatch workspace 4\" :onrightclick \"hyprctl dispatch workspace 4\" :class \"workspace $a4 $o4 $f4\" \"${ic[3]}\") \
      (button :onclick \"hyprctl dispatch workspace 5\" :onrightclick \"hyprctl dispatch workspace 5\" :class \"workspace $a5 $o5 $f5\" \"${ic[4]}\") \
      (button :onclick \"hyprctl dispatch workspace 6\" :onrightclick \"hyprctl dispatch workspace 6\" :class \"workspace $a6 $o6 $f6\" \"${ic[5]}\") \
      (button :onclick \"hyprctl dispatch workspace 7\" :onrightclick \"hyprctl dispatch workspace 7\" :class \"workspace $a7 $o7 $f7\" \"${ic[6]}\") \
      (button :onclick \"hyprctl dispatch workspace 8\" :onrightclick \"hyprctl dispatch workspace 8\" :class \"workspace $a8 $o8 $f8\" \"${ic[7]}\") \
      (button :onclick \"hyprctl dispatch workspace 9\" :onrightclick \"hyprctl dispatch workspace 9\" :class \"workspace $a9 $o9 $f9\" \"${ic[8]}\") \
    ) \
  )"
}

# initial render
workspaces

# listen to events and re-render
while true; do
  # TODO: not sure why this socat | read invocation seems to stop?
  socat - "UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
    workspaces "$line"
  done
done
echo '(box "DONE")'
