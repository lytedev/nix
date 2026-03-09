# OpenCode Sessions

OpenCode stores session data in SQLite databases at `~/.local/share/opencode/`.
The built-in `opencode session list` only shows sessions for the current
directory. The TUI session picker (`Ctrl+X L` or `/sessions`) also filters by
current directory.

**Versioned databases:** OpenCode uses separate DB files per release channel:
- `opencode-stable.db` — used by stable releases (e.g. 1.2.22)
- `opencode.db` — used by dev/unstable builds

Sessions created with one channel are invisible to the other. After upgrading
channels, migrate old sessions with export/import (see below).

## Querying sessions across all projects

```bash
# List all sessions sorted by most recently updated (stable DB)
nix shell nixpkgs#sqlite -c sqlite3 -header -column \
  ~/.local/share/opencode/opencode-stable.db \
  "SELECT datetime(COALESCE(NULLIF(time_updated,0), time_created) / 1000, 'unixepoch', 'localtime') as updated, title, REPLACE(REPLACE(directory, '/home/daniel/.home/', '~/'), '/home/daniel/', '~/') as dir FROM session ORDER BY COALESCE(NULLIF(time_updated,0), time_created) DESC"

# Count sessions per project
nix shell nixpkgs#sqlite -c sqlite3 -header -column \
  ~/.local/share/opencode/opencode-stable.db \
  "SELECT directory, COUNT(*) as sessions FROM session GROUP BY directory ORDER BY sessions DESC"
```

Note: timestamps in the DB are **milliseconds** since epoch (divide by 1000 for
`datetime()`).

## Migrating sessions across opencode versions

When upgrading opencode channels (e.g. dev -> stable), sessions in the old DB
won't appear. Use the old version via `nix shell` to export, then import into
the current version:

```bash
# Export all sessions from the old (non-stable) DB using the matching version
mkdir -p /tmp/opencode-migrate
nix shell nixpkgs#sqlite -c sqlite3 ~/.local/share/opencode/opencode.db \
  "SELECT id FROM session" > /tmp/opencode-migrate/ids.txt

while IFS= read -r sid; do
  nix shell nixpkgs#opencode -c opencode export "$sid" \
    > "/tmp/opencode-migrate/${sid}.json" 2>/dev/null
done < /tmp/opencode-migrate/ids.txt

# Import into the current (stable) version
for f in /tmp/opencode-migrate/ses_*.json; do
  opencode import "$f" 2>&1
done

rm -rf /tmp/opencode-migrate
```

If the nixpkgs opencode version doesn't match the old sessions, you may need to
build a specific version. Check what versions exist in the old DB with:

```bash
nix shell nixpkgs#sqlite -c sqlite3 ~/.local/share/opencode/opencode.db \
  "SELECT version, COUNT(*) FROM session GROUP BY version ORDER BY COUNT(*) DESC"
```

### Fixing project_id after import

`opencode import` assigns all imported sessions `project_id = 'global'` instead
of the correct project. The TUI filters sessions by project, so imported
sessions won't appear in the session picker until this is fixed.

**Step 1:** Copy missing project entries from the old DB. Check what's missing:

```bash
# List projects in old DB
nix shell nixpkgs#sqlite -c sqlite3 ~/.local/share/opencode/opencode.db \
  "SELECT id, worktree FROM project"

# List projects in stable DB
nix shell nixpkgs#sqlite -c sqlite3 ~/.local/share/opencode/opencode-stable.db \
  "SELECT id, worktree FROM project"
```

Insert any missing projects into the stable DB (adjust values as needed):

```bash
nix shell nixpkgs#sqlite -c sqlite3 ~/.local/share/opencode/opencode-stable.db "
INSERT OR IGNORE INTO project (id, worktree, vcs, name, icon_url, icon_color, time_created, time_updated, sandboxes)
VALUES ('<id>', '<worktree_path>', 'git', '', '', '', $(date +%s)000, $(date +%s)000, '[]');
"
```

**Step 2:** Remap sessions to matching projects by directory:

```bash
nix shell nixpkgs#sqlite -c sqlite3 ~/.local/share/opencode/opencode-stable.db "
-- Match sessions to projects by longest directory prefix
UPDATE session
SET project_id = (
  SELECT p.id FROM project p
  WHERE p.id != 'global'
    AND session.directory LIKE p.worktree || '%'
  ORDER BY LENGTH(p.worktree) DESC
  LIMIT 1
)
WHERE project_id = 'global'
AND EXISTS (
  SELECT 1 FROM project p
  WHERE p.id != 'global'
    AND session.directory LIKE p.worktree || '%'
);

-- Map opencode worktree dirs (contain project ID in path)
UPDATE session
SET project_id = SUBSTR(
  directory,
  LENGTH('/home/daniel/.home/.local/share/opencode/worktree/') + 1,
  40
)
WHERE project_id = 'global'
AND directory LIKE '/home/daniel/.home/.local/share/opencode/worktree/%'
AND EXISTS (
  SELECT 1 FROM project WHERE id = SUBSTR(
    directory,
    LENGTH('/home/daniel/.home/.local/share/opencode/worktree/') + 1,
    40
  )
);
"
```

**Step 3:** Verify the fix:

```bash
nix shell nixpkgs#sqlite -c sqlite3 ~/.local/share/opencode/opencode-stable.db \
  "SELECT project_id, COUNT(*) FROM session GROUP BY project_id ORDER BY COUNT(*) DESC"
```

Sessions in misc directories (`/`, `~`, `~/.config`) will remain as `global` —
this is expected since they don't belong to a specific project.
