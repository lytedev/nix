# shellcheck shell=bash
# Lightweight listener for claude notification forwarding via SSH reverse tunnel.
# Run this on the client machine, then SSH with: ssh -R 19199:localhost:19199 <host>
# Notifications from the remote host will be played locally.

# NOTIFY_PORT is injected by nix preamble
PORT="${NOTIFY_PORT:-19199}"
echo "Listening for claude notifications on port $PORT..." >&2

while true; do
  JSON="$(socat -t2 "TCP-LISTEN:${PORT},reuseaddr" - 2>/dev/null)" || continue
  [ -z "$JSON" ] && continue

  TITLE="$(echo "$JSON" | jq -r '.title // "claude"')"
  BODY="$(echo "$JSON" | jq -r '.body // ""')"
  URGENCY="$(echo "$JSON" | jq -r '.urgency // "normal"')"
  TYPE="$(echo "$JSON" | jq -r '.type // ""')"
  FROM="$(echo "$JSON" | jq -r '.from // ""')"

  CLAUDE_NOTIFY_LOCAL=1 claude-notify \
    --title "$TITLE" --body "$BODY" --urgency "$URGENCY" --type "$TYPE" --from "$FROM" &
done
