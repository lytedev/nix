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
PETNAMES_DIR="$STATE_DIR/petnames"
mkdir -p "$SESSIONS_DIR" "$PETNAMES_DIR"

# Read hook data from stdin (with timeout to avoid hanging on empty stdin)
if [ -t 0 ]; then
  HOOK_DATA="{}"
else
  HOOK_DATA="$(cat)"
fi
: "${HOOK_DATA:="{}"}"

SESSION_ID="$(echo "$HOOK_DATA" | jq -r '.session_id // empty')"
: "${SESSION_ID:=unnamed}"

# cwd this hook event ran in (from payload, else the process cwd). Defined
# early because resolve_session_name needs it to derive the project name.
HOOK_CWD="$(echo "$HOOK_DATA" | jq -r '.cwd // empty')"
: "${HOOK_CWD:=$(pwd)}"

# True if the argument looks like a Claude session UUID (8-4-4-4-12 hex).
# Claude's .session_name often carries the raw session id, which makes a
# useless tab name — treat it as "unnamed" and fall back to the default.
is_uuid() {
  [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

# Name of the project containing $HOOK_CWD: walk up to the first dir holding a
# .git or .jj entry and use its basename; fall back to the cwd basename. Pure
# bash + coreutils so we don't need git/jj in runtimeInputs.
project_name() {
  local dir="$HOOK_CWD"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -e "$dir/.git" ] || [ -e "$dir/.jj" ]; then
      basename "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  basename "$HOOK_CWD"
}

# A stable petname persisted per-session-id (survives across hook invocations).
session_petname() {
  local pn_file="$PETNAMES_DIR/$SESSION_ID"
  if [ -s "$pn_file" ]; then
    cat "$pn_file"
    return
  fi
  local pn
  pn="$(petname 2>/dev/null || true)"
  : "${pn:=$SESSION_ID}"
  printf '%s' "$pn" >"$pn_file"
  printf '%s' "$pn"
}

# Resolve a human-readable session name. Priority:
#   1. CLAUDE_SESSION_NAME env (claude-ws workspaces set this)
#   2. An explicit title from the payload (.session_title / .session_name),
#      IF it's a real name (a bare session UUID doesn't count). Set by
#      Claude's /rename. This is persisted (see below) because Claude only
#      includes the title in *some* hook event payloads — without persistence
#      the name would flap back to the default on every event that omits it.
#   3. A previously-persisted explicit title for this session id.
#   4. Default "$PROJECT:$PETNAME" (e.g. nix:optimal-surfbird), so a freshly
#      started session gets a meaningful, project-scoped tab name instead of a
#      context-free petname.
resolve_session_name() {
  if [ -n "${CLAUDE_SESSION_NAME:-}" ]; then
    printf '%s' "$CLAUDE_SESSION_NAME"
    return
  fi
  local title_file="$PETNAMES_DIR/$SESSION_ID.title"
  local from_payload
  from_payload="$(echo "$HOOK_DATA" | jq -r '.session_title // .session_name // empty')"
  if [ -n "$from_payload" ] && ! is_uuid "$from_payload"; then
    printf '%s' "$from_payload" >"$title_file"
    printf '%s' "$from_payload"
    return
  fi
  if [ -s "$title_file" ]; then
    cat "$title_file"
    return
  fi
  printf '%s:%s' "$(project_name)" "$(session_petname)"
}

# Resolve the zellij tab_id of the tab containing the current pane.
# Uses $ZELLIJ_PANE_ID (stable pane ID set by zellij) and queries list-panes.
# Echoes the tab_id on success, nothing on failure.
zellij_tab_id_for_current_pane() {
  [ -n "${ZELLIJ_PANE_ID:-}" ] || return 0
  zellij action list-panes --json 2>/dev/null \
    | jq -r --arg pid "$ZELLIJ_PANE_ID" \
        '.[] | select(.id == ($pid|tonumber)) | .tab_id' \
    | head -1
}

# Rename the zellij tab CONTAINING THIS PANE to $SESSION_NAME, but only if
# the name has changed since the last invocation for this session. Lets
# /rename (and any other later-arriving name source) propagate to the tab on
# the next hook event.
#
# Plain `zellij action rename-tab <name>` operates on the *currently focused*
# tab in the session — which may be a completely different tab if the user
# has switched away. Use rename-tab-by-id with the tab id resolved from our
# own pane id so we always target our own tab.
sync_zellij_tab_name() {
  [ -n "${ZELLIJ:-}" ] || return 0
  local applied_file="$PETNAMES_DIR/$SESSION_ID.tab-applied"
  local last_applied=""
  [ -s "$applied_file" ] && last_applied="$(cat "$applied_file")"
  if [ "$last_applied" != "$SESSION_NAME" ]; then
    local tab_id
    tab_id="$(zellij_tab_id_for_current_pane)"
    if [ -n "$tab_id" ]; then
      zellij action rename-tab-by-id "$tab_id" "$SESSION_NAME" 2>/dev/null || true
      printf '%s' "$SESSION_NAME" >"$applied_file"
    fi
  fi
}

SESSION_NAME="$(resolve_session_name)"

# Build from-URI: user@host:/cwd?pid=N&zellij=session.tab.pane
FROM_URI="$(whoami 2>/dev/null || echo unknown)@$(hostname -s 2>/dev/null || echo unknown):${HOOK_CWD}"

urlencode() { jq -rn --arg v "$1" '$v|@uri'; }

QUERY_PARTS=()
QUERY_PARTS+=("session=$(urlencode "$SESSION_ID")")
QUERY_PARTS+=("pid=$$")
if [ -n "${ZELLIJ:-}" ]; then
  ZJ_SESSION="${ZELLIJ_SESSION_NAME:-}"
  # Resolve OUR tab's name via list-panes — query-tab-names returns every tab
  # name in arbitrary order, so | head -1 yields whatever tab happens to be
  # first, not the one this pane lives in.
  ZJ_TAB="$(zellij action list-panes --json 2>/dev/null \
    | jq -r --arg pid "${ZELLIJ_PANE_ID:-}" \
        '.[] | select(.id == ($pid|tonumber)) | .tab_name' \
    | head -1 || true)"
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

touch_ws_activity() {
  # If this session is part of a claude-ws workspace, update its activity mtime.
  # Optional arg: last prompt text (truncated to 200 chars and stored).
  [ -n "${CLAUDE_SESSION_NAME:-}" ] || return 0
  local state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
  local ws_state="$state_home/claude-ws/$CLAUDE_SESSION_NAME"
  [ -d "$ws_state" ] || return 0
  touch "$ws_state/last-message"
  if [ $# -ge 1 ] && [ -n "$1" ]; then
    printf '%s' "${1:0:200}" >"$ws_state/last-prompt" 2>/dev/null || true
  fi
}

# Keep the zellij tab name in sync on every event, so a later /rename reflects
# on the next hook firing.
sync_zellij_tab_name

case "$SUBCOMMAND" in
  session-start)
    write_status "working" "Session started"
    ;;
  notification)
    NOTIFICATION_TYPE="$(echo "$HOOK_DATA" | jq -r '.type // empty')"
    MESSAGE="$(echo "$HOOK_DATA" | jq -r '.message // "Needs attention"')"

    # Label the notification with the resolved session name (the same name used
    # for the zellij tab and the session state file). resolve_session_name()
    # already prefers an explicit /rename title or workspace name and only falls
    # back to "$PROJECT:$PETNAME" — never a bare cwd basename.
    SESSION_LABEL="$SESSION_NAME"

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
    touch_ws_activity
    ;;
  user-prompt)
    write_status "working" "User prompt submitted"
    touch_ws_activity "$(echo "$HOOK_DATA" | jq -r '.prompt // empty')"
    ;;
  session-end)
    rm -f "$SESSION_FILE" "$PETNAMES_DIR/$SESSION_ID" "$PETNAMES_DIR/$SESSION_ID.tab-applied"
    ;;
  *)
    echo "Unknown subcommand: $SUBCOMMAND" >&2
    exit 1
    ;;
esac
