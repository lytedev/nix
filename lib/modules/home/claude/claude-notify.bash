# shellcheck shell=bash
TITLE="claude"
BODY=""
URGENCY="normal"
EVENT_TYPE=""
FROM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)   TITLE="$2"; shift 2 ;;
    --body)    BODY="$2"; shift 2 ;;
    --urgency) URGENCY="$2"; shift 2 ;;
    --type)    EVENT_TYPE="$2"; shift 2 ;;
    --from)    FROM="$2"; shift 2 ;;
    *)
      echo "Warning: unknown arg: $1" >&2
      shift
      ;;
  esac
done

# Notification forwarding via SSH reverse tunnel.
# If a listener is on localhost:NOTIFY_PORT (via `ssh -R PORT:localhost:PORT`),
# forward the notification as JSON. Falls through to local on connection refused.
# CLAUDE_NOTIFY_LOCAL=1 skips this (set by the listener to prevent loops).
FORWARDED=""
if [ "${CLAUDE_NOTIFY_LOCAL:-}" != "1" ]; then
  PORT="${NOTIFY_PORT:-19199}"
  JSON="$(jq -n \
    --arg title "$TITLE" \
    --arg body "$BODY" \
    --arg urgency "$URGENCY" \
    --arg type "$EVENT_TYPE" \
    --arg from "$FROM" \
    '{title: $title, body: $body, urgency: $urgency, type: $type, from: $from}')"
  if echo "$JSON" | socat -t2 - "TCP:localhost:${PORT}" 2>/dev/null; then
    FORWARDED=1
  fi
fi

if [ -z "$FORWARDED" ]; then
  # Desktop notification with action to focus the claude session
  # Parse niri_window and zellij info from the from-URI query string
  NIRI_WINDOW=""
  ZELLIJ_TAB=""
  if [ -n "$FROM" ]; then
    QUERY="${FROM#*\?}"
    if [ "$QUERY" != "$FROM" ]; then
      NIRI_WINDOW="$(echo "$QUERY" | tr '&' '\n' | sed -n 's/^niri_window=//p')"
      # extract zellij session.tab.pane -> tab is the middle part
      ZJ_VAL="$(echo "$QUERY" | tr '&' '\n' | sed -n 's/^zellij=//p')"
      if [ -n "$ZJ_VAL" ]; then
        ZELLIJ_TAB="$(echo "$ZJ_VAL" | cut -d. -f2)"
      fi
    fi
  fi

  if [ -n "$NIRI_WINDOW" ]; then
    # Actionable notification: focus window on click (runs in background)
    (
      ACTION=$(notify-send \
        -a "claude" \
        -u "$URGENCY" \
        -h "string:x-dunst-stack-tag:claude" \
        -h "string:x-niri-stack-tag:claude" \
        -A "focus=Focus" \
        "$TITLE" "$BODY" 2>/dev/null) || true
      if [ "$ACTION" = "focus" ]; then
        niri msg action focus-window --id "$NIRI_WINDOW" 2>/dev/null || true
        if [ -n "$ZELLIJ_TAB" ]; then
          zellij action go-to-tab-name "$ZELLIJ_TAB" 2>/dev/null || true
        fi
      fi
    ) &
  else
    notify-send \
      -a "claude" \
      -u "$URGENCY" \
      -h "string:x-dunst-stack-tag:claude" \
      -h "string:x-niri-stack-tag:claude" \
      "$TITLE" "$BODY" || true
  fi

  # Audio notification: pick a random sound based on event type
  # SFX_DIR and SFX_VOLUME are injected by nix preamble
  play_random_sound() {
    local pattern="$1"
    local dir="${SFX_DIR:-}"
    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
      return
    fi

    shopt -s nullglob
    # shellcheck disable=SC2206
    local -a files=("$dir"/${pattern}*.wav "$dir"/${pattern}*.mp3)
    shopt -u nullglob

    if [ ${#files[@]} -eq 0 ]; then
      return
    fi

    local pick="${files[RANDOM % ${#files[@]}]}"
    pw-play --volume "${SFX_VOLUME:-1.0}" "$pick" &>/dev/null || true
  }

  case "$EVENT_TYPE" in
    idle) play_random_sound "PeonWhat" ;;
    permission) play_random_sound "PeonAngry" ;;
    start) play_random_sound "PeonReady" ;;
    stop) play_random_sound "PeonYes" ;;
    *) play_random_sound "PeonWhat" ;;
  esac
fi

# Matrix notification via webhook — always from the original host (skip on forwarded calls)
if [ "${CLAUDE_NOTIFY_LOCAL:-}" != "1" ]; then
  NOTIFY_FILE="${WEBHOOKS_DIR:-}/notify"
  if [ -r "$NOTIFY_FILE" ]; then
    WEBHOOK_URL="$(cat "$NOTIFY_FILE")"
    if [ -n "$WEBHOOK_URL" ]; then
      MATRIX_MSG="$TITLE: $BODY"
      [ -n "$FROM" ] && MATRIX_MSG="$MATRIX_MSG
from $FROM"

      curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg text "$MATRIX_MSG" '{text: $text}')" \
        "$WEBHOOK_URL" &>/dev/null || true
    fi
  fi
fi
