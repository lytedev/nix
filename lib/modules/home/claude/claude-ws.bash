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
  claude-ws ls              list existing workspaces
  claude-ws -h | --help     show this help
USAGE
}

list_workspaces() {
  # TSV: name\trepo_basename\trepo_path   (repo cols empty if unknown)
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
    printf '%s\t%s\t%s\n' "$name" "$repo_base" "$repo_path"
  done
}

format_list() {
  # Read TSV, output aligned columns for human/fzf display.
  awk -F'\t' '{ printf "%-30s  %-20s  %s\n", $1, $2, $3 }'
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
  "")
    if ! command -v fzf >/dev/null; then
      echo "claude-ws: fzf not found; pass a <name> arg" >&2
      exit 2
    fi
    PICK="$(list_workspaces | format_list | fzf --prompt='workspace> ' --height=40% --reverse)" || exit 1
    NAME="$(printf '%s\n' "$PICK" | awk '{print $1}')"
    [ -n "$NAME" ] || exit 1
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
fi

mkdir -p "$STATE_DIR"
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
