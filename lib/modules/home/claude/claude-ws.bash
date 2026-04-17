# shellcheck shell=bash
# claude-ws <name>
# Launch Claude Code in an isolated jj workspace rooted at
# $XDG_DATA_HOME/code-workspace/<name>. Per-workspace metadata is kept
# outside the tree at $XDG_STATE_HOME/claude-ws/<name>/ so the workspace
# working copy stays pristine. Session gets --name <name> and a persistent
# --session-id. Inside zellij, runs in a new tab named <name>; re-running
# focuses the existing tab.

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
WS_ROOT="$DATA_HOME/code-workspace"
WS_STATE_ROOT="$STATE_HOME/claude-ws"

usage() {
  cat <<'USAGE'
usage:
  claude-ws                 fuzzy-pick existing workspace and launch
  claude-ws <name>          create-or-resume workspace <name>
  claude-ws ls              list existing workspaces with timestamps
  claude-ws rm [<name>]     delete workspace (fuzzy-pick if name omitted)
  claude-ws -h | --help     show this help
USAGE
}

# Map filesystem path to claude's projects dir name (/ . : → -).
escape_path() {
  printf '%s' "$1" | tr '/.:' '---'
}

stat_mtime() {
  # arg: path. Echo mtime unix ts, or empty if missing.
  [ -e "$1" ] || return 0
  stat -c %Y "$1" 2>/dev/null || true
}

# Migrate in-tree .claude-ws/ metadata to out-of-tree state dir.
# arg: workspace name. Idempotent.
migrate_state() {
  local name="$1"
  local old="$WS_ROOT/$name/.claude-ws"
  local new="$WS_STATE_ROOT/$name"
  [ -d "$old" ] || return 0
  if [ ! -d "$new" ]; then
    mkdir -p "$WS_STATE_ROOT"
    mv "$old" "$new"
  else
    # Both exist — merge any missing files, then drop the old dir.
    local f
    for f in "$old"/*; do
      [ -e "$f" ] || continue
      local bn
      bn="$(basename "$f")"
      [ -e "$new/$bn" ] || mv "$f" "$new/$bn"
    done
    rm -rf "$old"
  fi
}

last_interaction_ts() {
  # arg: workspace name. Prefer $WS_STATE_ROOT/<name>/last-message (written
  # by claude-hook on user-prompt/stop), fall back to the session's jsonl
  # mtime.
  local name="$1"
  local state_dir="$WS_STATE_ROOT/$name"
  local lm="$state_dir/last-message"
  if [ -e "$lm" ]; then
    stat_mtime "$lm"
    return
  fi
  local sid_file="$state_dir/session-id"
  [ -f "$sid_file" ] || return 0
  local sid
  sid="$(cat "$sid_file")"
  local ws_dir="$WS_ROOT/$name"
  local escaped
  escaped="$(escape_path "$ws_dir")"
  local jsonl="$HOME/.claude/projects/$escaped/$sid.jsonl"
  stat_mtime "$jsonl"
}

list_workspaces() {
  # TSV: name\trepo_basename\trepo_path\tcreated_ts\taccessed_ts\tmsg_ts
  [ -d "$WS_ROOT" ] || return 0
  for dir in "$WS_ROOT"/*/; do
    name="$(basename "$dir")"
    migrate_state "$name"
    state_dir="$WS_STATE_ROOT/$name"
    [ -d "$state_dir" ] || continue
    repo_path=""
    if [ -f "$state_dir/repo" ]; then
      repo_path="$(cat "$state_dir/repo")"
    fi
    repo_base=""
    [ -n "$repo_path" ] && repo_base="$(basename "$repo_path")"
    created_ts=""
    if [ -f "$state_dir/created" ]; then
      created_ts="$(cat "$state_dir/created")"
    else
      created_ts="$(stat_mtime "$state_dir")"
    fi
    accessed_ts="$(stat_mtime "$state_dir/last-accessed")"
    [ -z "$accessed_ts" ] && accessed_ts="$created_ts"
    msg_ts="$(last_interaction_ts "$name")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$name" "$repo_base" "$repo_path" "$created_ts" "$accessed_ts" "$msg_ts"
  done
}

format_list() {
  # Read TSV → aligned columns: name  repo  created  accessed  last-msg  path
  awk -F'\t' -v now="$(date +%s)" '
    function rel(ts,  d) {
      if (ts == "" || ts == 0) return "-"
      d = now - ts
      if (d < 60) return d "s"
      if (d < 3600) return int(d/60) "m"
      if (d < 86400) return int(d/3600) "h"
      if (d < 2592000) return int(d/86400) "d"
      return int(d/2592000) "mo"
    }
    { printf "%-24s  %-18s  %6s  %6s  %6s  %s\n",
      $1, $2, rel($4), rel($5), rel($6), $3 }
  '
}

pick_workspace() {
  # Fuzzy-pick and echo the chosen name, or exit 1 if cancelled.
  if ! command -v fzf >/dev/null; then
    echo "claude-ws: fzf not found; pass a <name> arg" >&2
    return 2
  fi
  local pick
  pick="$(list_workspaces | format_list | fzf \
    --prompt='workspace> ' --height=40% --reverse \
    --header='  NAME                      REPO                  CREATED  ACCESS  LASTMSG  PATH')" || return 1
  [ -n "$pick" ] || return 1
  printf '%s\n' "$pick" | awk '{print $1}'
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  ls)
    list_workspaces | format_list
    exit 0
    ;;
  rm)
    NAME="${2:-}"
    if [ -z "$NAME" ]; then
      NAME="$(pick_workspace)" || exit $?
    fi
    WS_PATH="$WS_ROOT/$NAME"
    STATE_DIR="$WS_STATE_ROOT/$NAME"
    if [ ! -d "$WS_PATH" ] && [ ! -d "$STATE_DIR" ]; then
      echo "claude-ws: no workspace '$NAME'" >&2
      exit 1
    fi
    read -r -p "delete workspace '$NAME' at $WS_PATH? [y/N] " ans
    case "$ans" in
      y | Y | yes | YES) ;;
      *)
        echo "aborted"
        exit 0
        ;;
    esac
    migrate_state "$NAME"
    repo=""
    [ -f "$STATE_DIR/repo" ] && repo="$(cat "$STATE_DIR/repo")"
    if [ -n "$repo" ] && [ -d "$repo/.jj" ]; then
      (cd "$repo" && jj workspace forget "$NAME" 2>/dev/null) || true
    fi
    rm -rf "$WS_PATH"
    rm -rf "$STATE_DIR"
    echo "removed $NAME"
    exit 0
    ;;
  "")
    NAME="$(pick_workspace)" || exit $?
    ;;
  -*)
    echo "claude-ws: unknown flag '$1'" >&2
    usage >&2
    exit 2
    ;;
  *)
    NAME="$1"
    ;;
esac

WS_PATH="$WS_ROOT/$NAME"
migrate_state "$NAME"
STATE_DIR="$WS_STATE_ROOT/$NAME"
SID_FILE="$STATE_DIR/session-id"

if [ ! -d "$WS_PATH/.jj" ]; then
  # Creating a new workspace — need an enclosing jj repo to add it to.
  dir="$PWD"
  while [ "$dir" != "/" ] && [ ! -d "$dir/.jj" ]; do
    dir="$(dirname "$dir")"
  done
  if [ ! -d "$dir/.jj" ]; then
    echo "claude-ws: no jj repo above $PWD to create workspace '$NAME' from" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$WS_PATH")"
  (cd "$dir" && jj workspace add --name "$NAME" "$WS_PATH")
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$dir" >"$STATE_DIR/repo"
  date +%s >"$STATE_DIR/created"
fi

mkdir -p "$STATE_DIR"
touch "$STATE_DIR/last-accessed"
if [ -f "$SID_FILE" ]; then
  SID="$(cat "$SID_FILE")"
  CLAUDE_ARGS=(--resume "$SID")
else
  SID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  printf '%s\n' "$SID" >"$SID_FILE"
  CLAUDE_ARGS=(--session-id "$SID")
fi

export CLAUDE_SESSION_NAME="$NAME"
# Inline env on the command so CLAUDE_SESSION_NAME reaches claude when spawned
# via `zellij action new-tab --` (which doesn't inherit caller env).
CLAUDE_CMD=(env "CLAUDE_SESSION_NAME=$NAME" claude --dangerously-skip-permissions --remote-control "$NAME" --name "$NAME" "${CLAUDE_ARGS[@]}")

if [ -n "${ZELLIJ:-}" ]; then
  if zellij action query-tab-names 2>/dev/null | grep -Fxq "$NAME"; then
    exec zellij action go-to-tab-name "$NAME"
  fi
  exec zellij action new-tab --cwd "$WS_PATH" --name "$NAME" -- "${CLAUDE_CMD[@]}"
fi

cd "$WS_PATH" || exit 1
exec "${CLAUDE_CMD[@]}"
