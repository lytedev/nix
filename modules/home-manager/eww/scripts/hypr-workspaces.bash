#!/usr/bin/env bash

#define icons for workspaces 1-9
ic=(1 2 3 4 5 6 7 8 9)

#initial check for occupied workspaces
for num in $(hyprctl workspaces | grep ID | sed 's/()/(1)/g' | awk 'NR>1{print $1}' RS='(' FS=')'); do 
  export o"$num"="$num"
done
 
#initial check for focused workspace
for num in $(hyprctl monitors | grep active | sed 's/()/(1)/g' | awk 'NR>1{print $1}' RS='(' FS=')'); do 
  export f"$num"="$num"
  export fnum=f"$num"
done

workspaces() {
  if [[ ${1:0:9} == "workspace" ]]; then
    # set focused workspace
    unset -v "$fnum"
    num=${1:11}
    export f"$num"="$num"
    export fnum=f"$num"
  elif [[ ${1:0:15} == "createworkspace" ]]; then 
    # set occupied workspace
    num=${1:17}
    export o"$num"="$num"
    export f"$num"="$num"
  elif [[ ${1:0:16} == "destroyworkspace" ]]; then
    # unset occupied workspace
    num=${1:18}
    unset -v o"$num" f"$num"
  fi

  # render eww widget
  echo "(eventbox :onscroll \"echo {} | sed -e 's/up/-1/g' -e 's/down/+1/g' | xargs hyprctl dispatch workspace\" \
    (box :class \"works\" :orientation \"h\" :spacing 5 :space-evenly \"true\" \
      (button :onclick \"hyprctl dispatch workspace 1\" :onrightclick \"hyprctl dispatch workspace 1\" :class \"ws_$o1$f1\" \"${ic[0]}\") \
      (button :onclick \"hyprctl dispatch workspace 2\" :onrightclick \"hyprctl dispatch workspace 2\" :class \"ws_$o2$f2\" \"${ic[1]}\") \
      (button :onclick \"hyprctl dispatch workspace 3\" :onrightclick \"hyprctl dispatch workspace 3\" :class \"ws_$o3$f3\" \"${ic[2]}\") \
      (button :onclick \"hyprctl dispatch workspace 4\" :onrightclick \"hyprctl dispatch workspace 4\" :class \"ws_$o4$f4\" \"${ic[3]}\") \
      (button :onclick \"hyprctl dispatch workspace 5\" :onrightclick \"hyprctl dispatch workspace 5\" :class \"ws_$o5$f5\" \"${ic[4]}\") \
      (button :onclick \"hyprctl dispatch workspace 6\" :onrightclick \"hyprctl dispatch workspace 6\" :class \"ws_$o6$f6\" \"${ic[5]}\") \
      (button :onclick \"hyprctl dispatch workspace 7\" :onrightclick \"hyprctl dispatch workspace 7\" :class \"ws_$o7$f7\" \"${ic[6]}\") \
      (button :onclick \"hyprctl dispatch workspace 8\" :onrightclick \"hyprctl dispatch workspace 8\" :class \"ws_$o8$f8\" \"${ic[7]}\") \
      (button :onclick \"hyprctl dispatch workspace 9\" :onrightclick \"hyprctl dispatch workspace 9\" :class \"ws_$o9$f9\" \"${ic[8]}\") \
    ) \
  )"
}

# initial render
workspaces

# listen to events and re-render
nc -u -l -U /tmp/hypr/"$HYPRLAND_INSTANCE_SIGNATURE"/.socket2.sock - | while read -r event; do 
  workspaces "$event"
done
