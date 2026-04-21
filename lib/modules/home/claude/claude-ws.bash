# shellcheck shell=bash
# claude-ws — manage and launch Claude Code sessions tied to isolated jj
# workspaces rooted at $XDG_DATA_HOME/code-workspace/<name>. Per-workspace
# metadata lives out-of-tree at $XDG_STATE_HOME/claude-ws/<name>/ so the
# workspace working copy stays pristine.

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
WS_ROOT="$DATA_HOME/code-workspace"
WS_STATE_ROOT="$STATE_HOME/claude-ws"
CLAUDE_PROJECTS="$HOME/.claude/projects"

usage() {
  cat <<'USAGE'
usage:
  claude-ws                      fuzzy-pick existing workspace and resume
  claude-ws new <name>           create workspace <name> from current jj repo, launch
  claude-ws <name>               resume existing workspace <name>
  claude-ws ls | list            list existing workspaces with timestamps
  claude-ws rm [<name>]          delete workspace (fuzzy-pick if omitted)
  claude-ws mv <old> <new>       rename workspace (jj + fs + claude project dir)
  claude-ws prune [<name>]       drop stale session-id for workspaces whose jsonl is missing
  claude-ws -h | --help          show this help
USAGE
}

escape_path() {
  # Map filesystem path to claude's projects dir name (/ . : → -).
  printf '%s' "$1" | tr '/.:' '---'
}

stat_mtime() {
  [ -e "$1" ] || return 0
  stat -c %Y "$1" 2>/dev/null || true
}

ws_jsonl_path() {
  # args: ws_path sid → echo expected jsonl path (may not exist).
  local ws_path="$1" sid="$2"
  local escaped
  escaped="$(escape_path "$ws_path")"
  printf '%s/%s/%s.jsonl' "$CLAUDE_PROJECTS" "$escaped" "$sid"
}

find_jsonl_by_sid() {
  # arg: sid → echo absolute path if found anywhere under ~/.claude/projects.
  local sid="$1"
  [ -d "$CLAUDE_PROJECTS" ] || return 1
  find "$CLAUDE_PROJECTS" -maxdepth 2 -type f -name "$sid.jsonl" 2>/dev/null | head -1
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
  # by claude-hook on user-prompt/stop), fall back to session jsonl mtime.
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
  stat_mtime "$(ws_jsonl_path "$WS_ROOT/$name" "$sid")"
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
    [ -f "$state_dir/repo" ] && repo_path="$(cat "$state_dir/repo")"
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

do_rm() {
  local name="$1"
  local ws_path="$WS_ROOT/$name"
  local state_dir="$WS_STATE_ROOT/$name"
  if [ ! -d "$ws_path" ] && [ ! -d "$state_dir" ]; then
    echo "claude-ws: no workspace '$name'" >&2
    return 1
  fi
  read -r -p "delete workspace '$name' at $ws_path? [y/N] " ans
  case "$ans" in y | Y | yes | YES) ;; *) echo "aborted"; return 0 ;; esac
  migrate_state "$name"
  local repo=""
  [ -f "$state_dir/repo" ] && repo="$(cat "$state_dir/repo")"
  if [ -n "$repo" ] && [ -d "$repo/.jj" ]; then
    (cd "$repo" && jj workspace forget "$name" 2>/dev/null) || true
  fi
  rm -rf "$ws_path" "$state_dir"
  echo "removed $name"
}

do_mv() {
  local old="$1" new="$2"
  local old_path="$WS_ROOT/$old"
  local new_path="$WS_ROOT/$new"
  local old_state="$WS_STATE_ROOT/$old"
  local new_state="$WS_STATE_ROOT/$new"
  [ -d "$old_path" ] || { echo "claude-ws: no workspace '$old'" >&2; return 1; }
  [ ! -e "$new_path" ] || { echo "claude-ws: workspace dir '$new' already exists" >&2; return 1; }
  [ ! -e "$new_state" ] || { echo "claude-ws: state dir '$new' already exists" >&2; return 1; }
  migrate_state "$old"
  local repo=""
  [ -f "$old_state/repo" ] && repo="$(cat "$old_state/repo")"
  if [ -n "$repo" ] && [ -d "$repo/.jj" ]; then
    (cd "$repo" && jj workspace rename "$old" "$new" 2>/dev/null) || {
      echo "claude-ws: jj workspace rename failed; aborting" >&2
      return 1
    }
  fi
  mv "$old_path" "$new_path"
  (cd "$new_path" && jj workspace update-stale 2>/dev/null) || true
  [ -d "$old_state" ] && mv "$old_state" "$new_state"
  local old_escaped new_escaped
  old_escaped="$(escape_path "$old_path")"
  new_escaped="$(escape_path "$new_path")"
  if [ -d "$CLAUDE_PROJECTS/$old_escaped" ]; then
    if [ -e "$CLAUDE_PROJECTS/$new_escaped" ]; then
      echo "claude-ws: $CLAUDE_PROJECTS/$new_escaped already exists; leaving old claude project in place" >&2
    else
      mv "$CLAUDE_PROJECTS/$old_escaped" "$CLAUDE_PROJECTS/$new_escaped"
    fi
  fi
  echo "renamed $old → $new"
}

do_prune_one() {
  local name="$1"
  local ws_path="$WS_ROOT/$name"
  local state_dir="$WS_STATE_ROOT/$name"
  local sid_file="$state_dir/session-id"
  [ -f "$sid_file" ] || return 0
  local sid jsonl found
  sid="$(cat "$sid_file")"
  jsonl="$(ws_jsonl_path "$ws_path" "$sid")"
  if [ -f "$jsonl" ]; then
    return 0
  fi
  found="$(find_jsonl_by_sid "$sid")" || found=""
  if [ -n "$found" ]; then
    local dest_dir
    dest_dir="$(dirname "$jsonl")"
    mkdir -p "$dest_dir"
    mv "$(dirname "$found")"/* "$dest_dir/" 2>/dev/null || true
    rmdir "$(dirname "$found")" 2>/dev/null || true
    echo "relocated claude project for $name → $dest_dir"
    return 0
  fi
  rm -f "$sid_file"
  echo "pruned stale session-id for $name"
}

do_prune() {
  local name="${1:-}"
  if [ -n "$name" ]; then
    do_prune_one "$name"
    return
  fi
  for dir in "$WS_ROOT"/*/; do
    [ -d "$dir" ] || continue
    local n
    n="$(basename "$dir")"
    migrate_state "$n"
    [ -d "$WS_STATE_ROOT/$n" ] || continue
    do_prune_one "$n"
  done
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  ls | list)
    list_workspaces | format_list
    exit 0
    ;;
  rm)
    NAME="${2:-}"
    if [ -z "$NAME" ]; then
      NAME="$(pick_workspace)" || exit $?
    fi
    do_rm "$NAME"
    exit $?
    ;;
  mv)
    [ -n "${2:-}" ] && [ -n "${3:-}" ] || { usage >&2; exit 2; }
    do_mv "$2" "$3"
    exit $?
    ;;
  prune)
    do_prune "${2:-}"
    exit 0
    ;;
  new)
    NAME="${2:-}"
    [ -n "$NAME" ] || { echo "claude-ws: 'new' requires <name>" >&2; exit 2; }
    MODE=new
    ;;
  "")
    NAME="$(pick_workspace)" || exit $?
    MODE=resume
    ;;
  -*)
    echo "claude-ws: unknown flag '$1'" >&2
    usage >&2
    exit 2
    ;;
  *)
    NAME="$1"
    MODE=resume
    ;;
esac

WS_PATH="$WS_ROOT/$NAME"
migrate_state "$NAME"
STATE_DIR="$WS_STATE_ROOT/$NAME"
SID_FILE="$STATE_DIR/session-id"

if [ "$MODE" = "new" ]; then
  if [ -d "$WS_PATH/.jj" ]; then
    echo "claude-ws: workspace '$NAME' already exists; use 'claude-ws $NAME' to resume" >&2
    exit 1
  fi
  dir="$PWD"
  while [ "$dir" != "/" ] && [ ! -e "$dir/.jj" ]; do
    dir="$(dirname "$dir")"
  done
  if [ ! -e "$dir/.jj" ]; then
    echo "claude-ws: no jj repo above $PWD to create workspace '$NAME' from" >&2
    exit 1
  fi
  # If we landed inside a secondary workspace, resolve to the main repo root.
  repo_root="$(cd "$dir" && jj workspace root 2>/dev/null || printf '%s' "$dir")"
  if [ -f "$repo_root/.jj/repo" ]; then
    main_jj="$(cd "$repo_root" && cd "$(cat .jj/repo)" && pwd)"
    repo_root="$(dirname "$main_jj")"
  fi
  mkdir -p "$(dirname "$WS_PATH")"
  (cd "$repo_root" && jj workspace add --name "$NAME" "$WS_PATH")
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$repo_root" >"$STATE_DIR/repo"
  date +%s >"$STATE_DIR/created"
elif [ ! -d "$WS_PATH/.jj" ]; then
  echo "claude-ws: workspace '$NAME' does not exist; create with 'claude-ws new $NAME'" >&2
  exit 1
fi

mkdir -p "$STATE_DIR"
touch "$STATE_DIR/last-accessed"
if [ -f "$SID_FILE" ]; then
  SID="$(cat "$SID_FILE")"
  EXPECTED_JSONL="$(ws_jsonl_path "$WS_PATH" "$SID")"
  if [ ! -f "$EXPECTED_JSONL" ]; then
    FOUND_JSONL="$(find_jsonl_by_sid "$SID")" || FOUND_JSONL=""
    if [ -n "$FOUND_JSONL" ]; then
      echo "claude-ws: session moved, relocating claude project dir" >&2
      mkdir -p "$(dirname "$EXPECTED_JSONL")"
      mv "$(dirname "$FOUND_JSONL")"/* "$(dirname "$EXPECTED_JSONL")/" 2>/dev/null || true
      rmdir "$(dirname "$FOUND_JSONL")" 2>/dev/null || true
    else
      echo "claude-ws: stored session $SID has no jsonl anywhere under $CLAUDE_PROJECTS" >&2
      read -r -p "drop session-id and start a fresh claude session? [y/N] " ans
      case "$ans" in
        y | Y | yes | YES)
          rm -f "$SID_FILE"
          SID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
          printf '%s\n' "$SID" >"$SID_FILE"
          CLAUDE_ARGS=(--session-id "$SID")
          ;;
        *)
          echo "aborted"
          exit 1
          ;;
      esac
    fi
  fi
  [ -z "${CLAUDE_ARGS+x}" ] && CLAUDE_ARGS=(--resume "$SID")
else
  SID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
  printf '%s\n' "$SID" >"$SID_FILE"
  CLAUDE_ARGS=(--session-id "$SID")
fi

export CLAUDE_SESSION_NAME="$NAME"
CLAUDE_CMD=(env "CLAUDE_SESSION_NAME=$NAME" claude --dangerously-skip-permissions --remote-control "$NAME" --name "$NAME" "${CLAUDE_ARGS[@]}")

if [ -n "${ZELLIJ:-}" ]; then
  if zellij action query-tab-names 2>/dev/null | grep -Fxq "$NAME"; then
    exec zellij action go-to-tab-name "$NAME"
  fi
  exec zellij action new-tab --cwd "$WS_PATH" --name "$NAME" -- "${CLAUDE_CMD[@]}"
fi

cd "$WS_PATH" || exit 1
exec "${CLAUDE_CMD[@]}"
