#!/usr/bin/env bash
# oc - fuzzy session/project picker for opencode

# Canonical DB (activation script consolidates all channel variants here)
DB="$HOME/.local/share/opencode/opencode.db"
if [[ ! -f "$DB" ]]; then
  # Fallback: try known variants in case consolidation hasn't run yet
  for variant in opencode-stable opencode-local; do
    f="$HOME/.local/share/opencode/$variant.db"
    if [[ -f "$f" ]]; then
      DB="$f"
      break
    fi
  done
fi
if [[ ! -f "$DB" ]]; then
  echo "No opencode database found" >&2
  exit 1
fi

mode="${1:-sessions}"

case "$mode" in
  s|sessions)
    selection=$(sqlite3 -separator $'\t' "$DB" "
      SELECT
        datetime(COALESCE(NULLIF(time_updated,0), time_created) / 1000, 'unixepoch', 'localtime'),
        title,
        REPLACE(REPLACE(directory, '$HOME/', '~/'), '/home/daniel/', '~/'),
        directory
      FROM session
      WHERE title NOT LIKE '%subagent%'
      ORDER BY COALESCE(NULLIF(time_updated,0), time_created) DESC
    " | fzf \
      --delimiter=$'\t' \
      --with-nth=1..3 \
      --header="Sessions (newest first)" \
      --preview-window=hidden \
      --bind="ctrl-p:toggle-preview" \
      --no-sort)
    ;;
  p|projects)
    selection=$(sqlite3 -separator $'\t' "$DB" "
      SELECT
        datetime(time_updated / 1000, 'unixepoch', 'localtime'),
        COALESCE(NULLIF(name, ''), REPLACE(REPLACE(worktree, '$HOME/', '~/'), '/home/daniel/', '~/')),
        REPLACE(REPLACE(worktree, '$HOME/', '~/'), '/home/daniel/', '~/'),
        worktree
      FROM project
      WHERE id != 'global'
      ORDER BY time_updated DESC
    " | fzf \
      --delimiter=$'\t' \
      --with-nth=1..3 \
      --header="Projects (newest first)" \
      --preview-window=hidden \
      --bind="ctrl-p:toggle-preview" \
      --no-sort)
    ;;
  *)
    echo "Usage: oc [sessions|projects]" >&2
    echo "  oc s  - pick a session (default)" >&2
    echo "  oc p  - pick a project" >&2
    exit 1
    ;;
esac

if [[ -z "$selection" ]]; then
  exit 0
fi

dir=$(echo "$selection" | awk -F$'\t' '{print $NF}')

if [[ ! -d "$dir" ]]; then
  echo "Directory not found: $dir" >&2
  exit 1
fi

cd "$dir" || exit 1
exec opencode
