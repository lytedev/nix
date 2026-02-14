# shellcheck shell=bash
TITLE="claude"
BODY=""
URGENCY="normal"
SESSION_NAME=""
EVENT_TYPE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      TITLE="$2"
      shift 2
      ;;
    --body)
      BODY="$2"
      shift 2
      ;;
    --urgency)
      URGENCY="$2"
      shift 2
      ;;
    --session-name)
      SESSION_NAME="$2"
      shift 2
      ;;
    --type)
      EVENT_TYPE="$2"
      shift 2
      ;;
    *)
      echo "Warning: unknown arg: $1" >&2
      shift
      ;;
  esac
done

if [ -n "$SESSION_NAME" ]; then
  TITLE="[$SESSION_NAME] $TITLE"
fi

# Desktop notification with stack tags for dedup
notify-send \
  -a "claude" \
  -u "$URGENCY" \
  -h "string:x-dunst-stack-tag:claude-$SESSION_NAME" \
  -h "string:x-niri-stack-tag:claude-$SESSION_NAME" \
  "$TITLE" "$BODY" || true

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

# Matrix notification via webhook (read URL from secret file)
WEBHOOK_URL=""
if [ -n "${CLAUDE_MATRIX_WEBHOOK_FILE:-}" ] && [ -r "${CLAUDE_MATRIX_WEBHOOK_FILE}" ]; then
  WEBHOOK_URL="$(cat "${CLAUDE_MATRIX_WEBHOOK_FILE}")"
fi
if [ -n "$WEBHOOK_URL" ]; then
  curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg text "$TITLE: $BODY" '{text: $text}')" \
    "$WEBHOOK_URL" &>/dev/null || true
fi
