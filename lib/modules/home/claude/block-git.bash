# shellcheck shell=bash
# PreToolUse hook: blocks `git` commands so jj (jujutsu) is used instead.
# Reads the Bash tool call JSON on stdin and denies any command invoking git.

if [ -t 0 ]; then
  HOOK_DATA="{}"
else
  HOOK_DATA="$(cat)"
fi

COMMAND="$(printf '%s' "$HOOK_DATA" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"

if printf '%s' "$COMMAND" | grep -qE '(^|;|\||&&|\|\|)[[:space:]]*git\b'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "git commands are blocked. Use jj (jujutsu) instead. See CLAUDE.md for the jj quick reference."
    }
  }'
fi
