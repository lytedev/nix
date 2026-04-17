# shellcheck shell=bash
# claude-ws <name>
# Launch Claude Code in an isolated jj workspace rooted at
# $XDG_DATA_HOME/code-workspace/<name>. Session gets --name <name> and a
# persistent --session-id. Inside zellij, runs in a new tab named <name>;
# re-running focuses the existing tab.

NAME="${1:-}"
if [ -z "$NAME" ]; then
  echo "usage: claude-ws <name>" >&2
  exit 2
fi

# Find enclosing jj repo root (search upward from cwd).
dir="$PWD"
while [ "$dir" != "/" ] && [ ! -d "$dir/.jj" ]; do
  dir="$(dirname "$dir")"
done
if [ ! -d "$dir/.jj" ]; then
  echo "claude-ws: no jj repo above $PWD" >&2
  exit 1
fi
REPO_ROOT="$dir"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
WS_PATH="$DATA_HOME/code-workspace/$NAME"
STATE_DIR="$WS_PATH/.claude-ws"
SID_FILE="$STATE_DIR/session-id"

if [ ! -d "$WS_PATH/.jj" ]; then
  mkdir -p "$(dirname "$WS_PATH")"
  (cd "$REPO_ROOT" && jj workspace add --name "$NAME" "$WS_PATH")
fi

mkdir -p "$STATE_DIR"
if [ -f "$SID_FILE" ]; then
  SID="$(cat "$SID_FILE")"
  CLAUDE_ARGS=(--resume "$SID")
else
  SID="$(uuidgen | tr 'A-Z' 'a-z')"
  printf '%s\n' "$SID" >"$SID_FILE"
  CLAUDE_ARGS=(--session-id "$SID")
fi

CLAUDE_CMD=(claude --dangerously-skip-permissions --name "$NAME" "${CLAUDE_ARGS[@]}")

if [ -n "${ZELLIJ:-}" ]; then
  if zellij action query-tab-names 2>/dev/null | grep -Fxq "$NAME"; then
    exec zellij action go-to-tab-name "$NAME"
  fi
  exec zellij action new-tab --cwd "$WS_PATH" --name "$NAME" -- "${CLAUDE_CMD[@]}"
fi

cd "$WS_PATH"
exec "${CLAUDE_CMD[@]}"
