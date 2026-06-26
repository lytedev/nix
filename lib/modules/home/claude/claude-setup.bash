# shellcheck shell=bash
# Install Claude Code hooks for notifications and session tracking.
# Idempotent: safe to run multiple times.
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
STATE_DIR="$HOME/.local/state/claude"
SESSIONS_DIR="$STATE_DIR/sessions"

# Create directories
mkdir -p "$SESSIONS_DIR"
mkdir -p "$HOME/.claude"

# Backup existing settings
if [ -f "$CLAUDE_SETTINGS" ]; then
  cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak.$(date +%s)"
  echo "Backed up existing settings to $CLAUDE_SETTINGS.bak.*"

  # Prune old backups, keeping only the last 5
  # shellcheck disable=SC2012
  mapfile -t old_backups < <(ls -1t "$CLAUDE_SETTINGS".bak.* 2>/dev/null | tail -n +6)
  for f in "${old_backups[@]}"; do
    rm -f "$f"
  done

  # Two-step merge: first strip existing nix-managed entries, then merge with new hooks
  # Step 1: Remove any existing nix-managed hook entries (claude-hook, block-git)
  #         from hook arrays so re-merging doesn't accumulate duplicates.
  STRIPPED="$(jq '
    if .hooks then
      .hooks |= with_entries(
        .value |= [.[] |
          . + {hooks: [(.hooks // [])[] | select(.command | test("claude-hook|block-git") | not)]}
        ] | [.[] | select((.hooks | length) > 0)]
      )
    else .
    end
  ' "$CLAUDE_SETTINGS")"

  # Step 2: Merge stripped settings with new hooks config using array concatenation
  MERGED="$(echo "$STRIPPED" | jq --argjson new_hooks "$HOOKS_CONFIG" '
    . as $base |
    $new_hooks.hooks as $nh |
    $base + {
      hooks: (($base.hooks // {}) as $eh |
        ($nh | keys) | reduce .[] as $key ($eh;
          .[$key] = ((.[$key] // []) + $nh[$key])
        )
      )
    }
  ')"

  # Write to tmpfile, validate, then move.
  # Also force cleanupPeriodDays so existing settings.json files pick it up
  # (the merge above only carries over hooks, not other top-level keys).
  TMPFILE="$(mktemp "$HOME/.claude/.settings.XXXXXX")"
  echo "$MERGED" | jq --argjson cpd "$CLEANUP_PERIOD_DAYS" '.cleanupPeriodDays = $cpd' >"$TMPFILE"

  # Validate: must be valid JSON and non-empty
  if ! jq empty "$TMPFILE" 2>/dev/null || [ ! -s "$TMPFILE" ]; then
    echo "Error: Generated settings are invalid. Aborting." >&2
    rm -f "$TMPFILE"
    exit 1
  fi

  mv "$TMPFILE" "$CLAUDE_SETTINGS"
else
  # No existing settings, write hooks config directly (with cleanupPeriodDays)
  TMPFILE="$(mktemp "$HOME/.claude/.settings.XXXXXX")"
  echo "$HOOKS_CONFIG" | jq --argjson cpd "$CLEANUP_PERIOD_DAYS" '.cleanupPeriodDays = $cpd' >"$TMPFILE"

  if ! jq empty "$TMPFILE" 2>/dev/null || [ ! -s "$TMPFILE" ]; then
    echo "Error: Generated settings are invalid. Aborting." >&2
    rm -f "$TMPFILE"
    exit 1
  fi

  mv "$TMPFILE" "$CLAUDE_SETTINGS"
fi

echo "Hooks installed in $CLAUDE_SETTINGS"
echo ""
echo "Notifications will fire for:"
echo "  - Session start/end"
echo "  - Idle prompts (desktop + optional Matrix)"
echo "  - Permission prompts (desktop + optional Matrix)"
echo ""
echo "For Matrix notifications, set CLAUDE_MATRIX_WEBHOOK in your environment."
