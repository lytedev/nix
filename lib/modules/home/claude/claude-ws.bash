# shellcheck shell=bash
# claude-ws <name>
# Launch Claude Code in an isolated jj workspace rooted at
# $XDG_DATA_HOME/code-workspace/<name>. Session gets --name <name> and a
# persistent --session-id. Inside zellij, runs in a new tab named <name>;
# re-running focuses the existing tab.

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
WS_ROOT="$DATA_HOME/code-workspace"

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

fmt_relative() {
  # arg: unix timestamp. Echo short relative label like "3h", "2d", "-".
  local ts="$1"
  if [ -z "$ts" ] || [ "$ts" = "0" ]; then
    printf '%s' "-"
    return
  fi
  local now delta
  now="$(date +%s)"
  delta=$((now - ts))
  if [ $delta -lt 60 ]; then printf '%ds' "$delta"
  elif [ $delta -lt 3600 ]; then printf '%dm' $((delta / 60))
  elif [ $delta -lt 86400 ]; then printf '%dh' $((delta / 3600))
  elif [ $delta -lt 2592000 ]; then printf '%dd' $((delta / 86400))
  else printf '%dmo' $((delta / 2592000))
  fi
}

stat_mtime() {
  # arg: path. Echo mtime unix ts, or empty if missing.
  [ -e "$1" ] || return 0
  stat -c %Y "$1" 2>/dev/null || true
}

last_interaction_ts() {
  # arg: ws_dir. Look up the session jsonl under ~/.claude/projects/<escaped>/<sid>.jsonl
  local ws_dir="$1"
  local sid_file="$ws_dir/.claude-ws/session-id"
  [ -f "$sid_file" ] || return 0
  local sid
  sid="$(cat "$sid_file")"
  local escaped
  escaped="$(escape_path "$ws_dir")"
  local jsonl="$HOME/.claude/projects/$escaped/$sid.jsonl"
  stat_mtime "$jsonl"
}

list_workspaces() {
  # TSV: name\trepo_basename\trepo_path\tcreated_ts\taccessed_ts\tmsg_ts
  [ -d "$WS_ROOT" ] || return 0
  for dir in "$WS_ROOT"/*/; do
    [ -d "$dir/.claude-ws" ] || continue
    name="$(basename "$dir")"
    repo_path=""
    if [ -f "$dir/.claude-ws/repo" ]; then
      repo_path="$(cat "$dir/.claude-ws/repo")"
    fi
    repo_base=""
    [ -n "$repo_path" ] && repo_base="$(basename "$repo_path")"
    created_ts=""
    if [ -f "$dir/.claude-ws/created" ]; then
      created_ts="$(cat "$dir/.claude-ws/created")"
    else
      created_ts="$(stat_mtime "$dir/.claude-ws")"
    fi
    accessed_ts="$(stat_mtime "$dir/.claude-ws/last-accessed")"
    [ -z "$accessed_ts" ] && accessed_ts="$created_ts"
    msg_ts="$(last_interaction_ts "$dir")"
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
    if [ ! -d "$WS_PATH" ]; then
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
    repo=""
    [ -f "$WS_PATH/.claude-ws/repo" ] && repo="$(cat "$WS_PATH/.claude-ws/repo")"
    if [ -n "$repo" ] && [ -d "$repo/.jj" ]; then
      (cd "$repo" && jj workspace forget "$NAME" 2>/dev/null) || true
    fi
    rm -rf "$WS_PATH"
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
STATE_DIR="$WS_PATH/.claude-ws"
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
CLAUDE_CMD=(env "CLAUDE_SESSION_NAME=$NAME" claude --dangerously-skip-permissions --name "$NAME" "${CLAUDE_ARGS[@]}")

if [ -n "${ZELLIJ:-}" ]; then
  if zellij action query-tab-names 2>/dev/null | grep -Fxq "$NAME"; then
    exec zellij action go-to-tab-name "$NAME"
  fi
  exec zellij action new-tab --cwd "$WS_PATH" --name "$NAME" -- "${CLAUDE_CMD[@]}"
fi

cd "$WS_PATH" || exit 1
exec "${CLAUDE_CMD[@]}"
