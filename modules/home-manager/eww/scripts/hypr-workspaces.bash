#!/usr/bin/env bash

# TODO: we're mixing bash arrays and not-arrays - get it together
declare -A OCCUPIED
declare -A ACTIVE
declare -A FOCUSED

#define icons for workspaces 1-9
spaces=(1 2 3 4 5 6 7 8 9)
icons=(1 2 3 4 5 6 7 8 9)

occupy() { export OCCUPIED["$1"]=occupied; }
unoccupy() { unset "OCCUPIED[$1]"; }

activate() { export ACTIVE["$1"]=active; }
deactivate() { unset "ACTIVE[$1]"; }

focus() { export FOCUSED["$1"]=focused; }
unfocus() { unset "FOCUSED[$1]"; }

workspaces() {
  for s in "${spaces[@]}"; do
    unfocus "$s"
    deactivate "$s"
    unoccupy "$s"
  done

  # TODO: avoid recomputing these each time and actually listen to the events?
  mons_json=$(hyprctl monitors -j)
  for num in $(hyprctl workspaces -j | jq -r '.[] | select(.windows > 0) | .id'); do 
    occupy "$num"
  done
 
  for num in $(echo "$mons_json" | jq -r '.[].activeWorkspace.id'); do 
    activate "$num"
  done

  for num in $(echo "$mons_json" | jq -r '.[] | select(.focused) | .activeWorkspace.id'); do 
    focus "$num"
  done

  # TODO: would be nice to have monitors' workspaces show up in left-to-right
  # order as laid out in physical/pixel space
  # this would make glancing at the workspace indicator more intuitive
  # 
  # TODO: might be nice to exclude certain windows as counting towards "occupation" such as xwaylandvideobridge or w/e
  # 
  # NOTE: maybe I can group workspaces by their monitor with some mechanism for "unassigned" workspace to show up by a "primary" monitor

  # render eww widget
  echo "(eventbox :onscroll \"echo {} | sed -e 's/up/-1/g' -e 's/down/+1/g' | xargs hyprctl dispatch workspace\" \
    (box :class \"workspaces\" :orientation \"h\" :spacing 0 :space-evenly \"true\" \
      (button :onclick \"hyprctl dispatch workspace 1\" :onrightclick \"hyprctl dispatch workspace 1\" :class \"workspace ${ACTIVE[1]} ${OCCUPIED[1]} ${FOCUSED[1]}\" \"${icons[0]}\") \
      (button :onclick \"hyprctl dispatch workspace 2\" :onrightclick \"hyprctl dispatch workspace 2\" :class \"workspace ${ACTIVE[2]} ${OCCUPIED[2]} ${FOCUSED[2]}\" \"${icons[1]}\") \
      (button :onclick \"hyprctl dispatch workspace 3\" :onrightclick \"hyprctl dispatch workspace 3\" :class \"workspace ${ACTIVE[3]} ${OCCUPIED[3]} ${FOCUSED[3]}\" \"${icons[2]}\") \
      (button :onclick \"hyprctl dispatch workspace 4\" :onrightclick \"hyprctl dispatch workspace 4\" :class \"workspace ${ACTIVE[4]} ${OCCUPIED[4]} ${FOCUSED[4]}\" \"${icons[3]}\") \
      (button :onclick \"hyprctl dispatch workspace 5\" :onrightclick \"hyprctl dispatch workspace 5\" :class \"workspace ${ACTIVE[5]} ${OCCUPIED[5]} ${FOCUSED[5]}\" \"${icons[4]}\") \
      (button :onclick \"hyprctl dispatch workspace 6\" :onrightclick \"hyprctl dispatch workspace 6\" :class \"workspace ${ACTIVE[6]} ${OCCUPIED[6]} ${FOCUSED[6]}\" \"${icons[5]}\") \
      (button :onclick \"hyprctl dispatch workspace 7\" :onrightclick \"hyprctl dispatch workspace 7\" :class \"workspace ${ACTIVE[7]} ${OCCUPIED[7]} ${FOCUSED[7]}\" \"${icons[6]}\") \
      (button :onclick \"hyprctl dispatch workspace 8\" :onrightclick \"hyprctl dispatch workspace 8\" :class \"workspace ${ACTIVE[8]} ${OCCUPIED[8]} ${FOCUSED[8]}\" \"${icons[7]}\") \
      (button :onclick \"hyprctl dispatch workspace 9\" :onrightclick \"hyprctl dispatch workspace 9\" :class \"workspace ${ACTIVE[9]} ${OCCUPIED[9]} ${FOCUSED[9]}\" \"${icons[8]}\") \
    ) \
  )"
}

workspace_reader() {
  while read -r l; do
    workspaces "$l"
  done
}

# initial render
workspaces

# listen to events and re-render
nc -U "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | workspace_reader

echo '(box "EXITING")'
