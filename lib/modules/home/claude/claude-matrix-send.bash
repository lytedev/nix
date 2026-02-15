# shellcheck shell=bash
# Send a message to a named Matrix room via hookshot webhook.
# Usage: claude-matrix-send <room-name> <message>
# Available rooms are symlinked in WEBHOOKS_DIR.

ROOM="${1:-}"
shift || true
MESSAGE="$*"

if [ -z "$ROOM" ] || [ -z "$MESSAGE" ]; then
  echo "Usage: claude-matrix-send <room-name> <message>" >&2
  echo "" >&2
  echo "Available rooms:" >&2
  if [ -d "${WEBHOOKS_DIR:-}" ]; then
    for f in "$WEBHOOKS_DIR"/*; do
      [ -e "$f" ] && echo "  $(basename "$f")" >&2
    done
  else
    echo "  (none configured)" >&2
  fi
  exit 1
fi

WEBHOOK_FILE="${WEBHOOKS_DIR:-}/$ROOM"
if [ ! -r "$WEBHOOK_FILE" ]; then
  echo "Error: unknown room '$ROOM'" >&2
  echo "Available rooms:" >&2
  for f in "$WEBHOOKS_DIR"/*; do
    [ -e "$f" ] && echo "  $(basename "$f")" >&2
  done
  exit 1
fi

WEBHOOK_URL="$(cat "$WEBHOOK_FILE")"
if [ -z "$WEBHOOK_URL" ]; then
  echo "Error: webhook file for '$ROOM' is empty" >&2
  exit 1
fi

curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg text "$MESSAGE" '{text: $text}')" \
  "$WEBHOOK_URL"
