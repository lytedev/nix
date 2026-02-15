# shellcheck shell=bash
# Hook entry point for Claude Code events.
# Fires for all Claude sessions. Writes session state and sends notifications.

SUBCOMMAND="${1:-}"
if [ -z "$SUBCOMMAND" ]; then
  echo "Usage: claude-hook <session-start|notification|stop|user-prompt|session-end>" >&2
  exit 1
fi

STATE_DIR="$HOME/.local/state/claude"
SESSIONS_DIR="$STATE_DIR/sessions"
mkdir -p "$SESSIONS_DIR"

# Read hook data from stdin (with timeout to avoid hanging on empty stdin)
if [ -t 0 ]; then
  HOOK_DATA="{}"
else
  HOOK_DATA="$(cat)"
fi
: "${HOOK_DATA:="{}"}"

SESSION_ID="$(echo "$HOOK_DATA" | jq -r '.session_id // empty')"
: "${SESSION_ID:=unnamed}"

# Use CLAUDE_SESSION_NAME if set (multi-session), otherwise derive from session_id
SESSION_NAME="${CLAUDE_SESSION_NAME:-${SESSION_ID}}"

SESSION_FILE="$SESSIONS_DIR/${SESSION_NAME}.json"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

write_status() {
  local status="$1"
  local message="${2:-}"

  local cwd
  cwd="$(echo "$HOOK_DATA" | jq -r '.cwd // empty')"
  if [ -z "$cwd" ]; then
    cwd="$(pwd)"
  fi

  local tmpfile
  tmpfile="$(mktemp "$SESSIONS_DIR/.tmp.XXXXXX")"

  local started_at="$NOW"
  if [ -f "$SESSION_FILE" ]; then
    started_at="$(jq -r '.started_at // empty' "$SESSION_FILE")"
    if [ -z "$started_at" ]; then
      started_at="$NOW"
    fi
  fi

  jq -n \
    --arg session_id "$SESSION_ID" \
    --arg name "$SESSION_NAME" \
    --arg cwd "$cwd" \
    --arg status "$status" \
    --arg started_at "$started_at" \
    --arg last_update "$NOW" \
    --arg last_message "$message" \
    '{
      session_id: $session_id,
      name: $name,
      cwd: $cwd,
      status: $status,
      started_at: $started_at,
      last_update: $last_update,
      last_message: $last_message
    }' >"$tmpfile"

  mv "$tmpfile" "$SESSION_FILE"
}

case "$SUBCOMMAND" in
  session-start)
    write_status "working" "Session started"
    ;;
  notification)
    NOTIFICATION_TYPE="$(echo "$HOOK_DATA" | jq -r '.type // empty')"
    MESSAGE="$(echo "$HOOK_DATA" | jq -r '.message // "Needs attention"')"

    if [ "$NOTIFICATION_TYPE" = "permission_prompt" ]; then
      write_status "permission" "$MESSAGE"
      claude-notify --type permission --title "Permission needed" --body "$MESSAGE" --urgency critical --session-name "$SESSION_NAME" || true
    else
      write_status "idle" "$MESSAGE"
      claude-notify --type idle --title "Session idle" --body "$MESSAGE" --urgency normal --session-name "$SESSION_NAME" || true
    fi
    ;;
  stop)
    write_status "idle" "Stopped"
    ;;
  user-prompt)
    write_status "working" "User prompt submitted"
    ;;
  session-end)
    rm -f "$SESSION_FILE"
    ;;
  *)
    echo "Unknown subcommand: $SUBCOMMAND" >&2
    exit 1
    ;;
esac
