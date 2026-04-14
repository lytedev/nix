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

# Build from-URI: user@host:/cwd?pid=N&zellij=session.tab.pane
HOOK_CWD="$(echo "$HOOK_DATA" | jq -r '.cwd // empty')"
: "${HOOK_CWD:=$(pwd)}"

FROM_URI="$(whoami 2>/dev/null || echo unknown)@$(hostname -s 2>/dev/null || echo unknown):${HOOK_CWD}"

urlencode() { jq -rn --arg v "$1" '$v|@uri'; }

QUERY_PARTS=()
QUERY_PARTS+=("session=$(urlencode "$SESSION_ID")")
QUERY_PARTS+=("pid=$$")
if [ -n "${ZELLIJ:-}" ]; then
  ZJ_SESSION="${ZELLIJ_SESSION_NAME:-}"
  ZJ_TAB="$(zellij action query-tab-names 2>/dev/null | head -1 || true)"
  ZJ_PANE="${ZELLIJ_PANE_ID:-}"
  ZJ="${ZJ_SESSION}${ZJ_TAB:+.$ZJ_TAB}${ZJ_PANE:+.$ZJ_PANE}"
  [ -n "$ZJ" ] && QUERY_PARTS+=("zellij=$(urlencode "$ZJ")")
fi

CLAUDE_TITLE="$(echo "$HOOK_DATA" | jq -r '.session_title // empty')"
[ -n "$CLAUDE_TITLE" ] && QUERY_PARTS+=("title=$(urlencode "$CLAUDE_TITLE")")

# Niri window ID for focus-on-click
NIRI_WINDOW="$(niri msg focused-window --json 2>/dev/null | jq -r '.id // empty' || true)"
[ -n "$NIRI_WINDOW" ] && QUERY_PARTS+=("niri_window=$NIRI_WINDOW")

QUERY=$(printf "&%s" "${QUERY_PARTS[@]}")
FROM_URI="${FROM_URI}?${QUERY:1}"

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

    # Build a session label: prefer session_title, fall back to cwd basename
    SESSION_LABEL=""
    if [ -n "$CLAUDE_TITLE" ]; then
      SESSION_LABEL="$CLAUDE_TITLE"
    else
      SESSION_LABEL="$(basename "$HOOK_CWD")"
    fi

    # Truncate message for desktop notification body (keep first 200 chars)
    NOTIFY_BODY="$MESSAGE"
    if [ "${#NOTIFY_BODY}" -gt 200 ]; then
      NOTIFY_BODY="${NOTIFY_BODY:0:197}..."
    fi

    if [ "$NOTIFICATION_TYPE" = "permission_prompt" ]; then
      write_status "permission" "$MESSAGE"
      claude-notify --type permission --title "Permission needed — $SESSION_LABEL" --body "$NOTIFY_BODY" --urgency critical --from "$FROM_URI" || true
    else
      write_status "idle" "$MESSAGE"
      claude-notify --type idle --title "Idle — $SESSION_LABEL" --body "$NOTIFY_BODY" --urgency normal --from "$FROM_URI" || true
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
