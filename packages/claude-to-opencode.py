#!/usr/bin/env python3
"""Convert Claude Code session JSONL files to OpenCode-importable JSON.

Usage:
  claude-to-opencode <session.jsonl> [--title "Session title"]
  claude-to-opencode --list [--project <path>]
  claude-to-opencode --all [--project <path>] [--out-dir <dir>]

Reads a Claude Code session (.jsonl) and writes OpenCode-compatible JSON to
stdout (or files with --all). The output can be imported with:
  opencode import <file.json>

Tool calls and results are preserved as readable text wrapped in XML-style
fences so they appear as normal conversation content in OpenCode.
"""

import argparse
import json
import os
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

CLAUDE_DIR = Path.home() / ".claude"
PROJECTS_DIR = CLAUDE_DIR / "projects"


def encode_project_path(path: str) -> str:
    """Encode a filesystem path to Claude's project directory name format."""
    return path.replace("/", "-")


def decode_project_path(encoded: str) -> str:
    """Best-effort decode of Claude's project directory name to a path.

    Claude encodes '/' as '-' and '.' as '-', so:
      /home/daniel/.home/Documents -> -home-daniel--home-Documents
    The '--' sequences represent '/.' (slash-dot).
    This is inherently lossy, but good enough for display.
    """
    if not encoded.startswith("-"):
        return encoded
    # Restore '/.' first (encoded as '--'), then remaining '-' as '/'
    result = "/" + encoded[1:].replace("--", "/.").replace("-", "/")
    return result


def _get_cwd_from_session(path: Path) -> str | None:
    """Read the cwd field from the first session entry that has one."""
    try:
        with open(path) as f:
            for line in f:
                obj = json.loads(line)
                cwd = obj.get("cwd")
                if cwd:
                    return cwd
    except Exception:
        pass
    return None


def list_sessions(project_filter: str | None = None):
    """List available Claude Code sessions."""
    if not PROJECTS_DIR.exists():
        print("No Claude Code projects directory found", file=sys.stderr)
        sys.exit(1)

    for project_dir in sorted(PROJECTS_DIR.iterdir()):
        if not project_dir.is_dir():
            continue

        project_path = decode_project_path(project_dir.name)
        if project_filter and project_filter not in project_path:
            continue

        sessions = sorted(project_dir.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
        if not sessions:
            continue

        for session_file in sessions:
            sid = session_file.stem
            mtime = datetime.fromtimestamp(session_file.stat().st_mtime, tz=timezone.utc)
            # Get first user message as title hint
            title = _get_session_title(session_file)
            display_path = _get_cwd_from_session(session_file) or project_path
            short_path = display_path.replace(str(Path.home()), "~")
            print(f"{mtime.strftime('%Y-%m-%d %H:%M')}  {sid}  {short_path}")
            if title:
                print(f"  {title[:120]}")


def _get_session_title(path: Path) -> str | None:
    """Extract the first user message text as a session title."""
    try:
        with open(path) as f:
            for line in f:
                obj = json.loads(line)
                if obj.get("type") != "user":
                    continue
                content = obj.get("message", {}).get("content", [])
                if isinstance(content, str):
                    return content.strip()[:150]
                if isinstance(content, list):
                    for block in content:
                        if isinstance(block, dict) and block.get("type") == "text":
                            return block["text"].strip()[:150]
    except Exception:
        pass
    return None


def _format_tool_use(block: dict) -> str:
    """Format a tool_use content block as readable fenced text."""
    name = block.get("name", "unknown_tool")
    inp = block.get("input", {})
    # Format input as readable key-value pairs
    if isinstance(inp, dict):
        parts = []
        for k, v in inp.items():
            sv = str(v)
            if len(sv) > 500:
                sv = sv[:500] + "... [truncated]"
            parts.append(f"  {k}: {sv}")
        input_text = "\n".join(parts)
    else:
        input_text = str(inp)[:2000]
    return f"<migrated_claude_code_tool_use tool=\"{name}\">\n{input_text}\n</migrated_claude_code_tool_use>"


def _format_tool_result(block: dict) -> str:
    """Format a tool_result content block as readable fenced text."""
    tool_use_id = block.get("tool_use_id", "?")
    is_error = block.get("is_error", False)
    content = block.get("content", "")
    tag = "migrated_claude_code_tool_error" if is_error else "migrated_claude_code_tool_result"

    if isinstance(content, list):
        # Content can be a list of blocks (text, image, etc)
        text_parts = []
        for part in content:
            if isinstance(part, dict) and part.get("type") == "text":
                text_parts.append(part["text"])
            elif isinstance(part, dict):
                text_parts.append(f"[{part.get('type', 'unknown')} content]")
        content_text = "\n".join(text_parts)
    else:
        content_text = str(content)

    if len(content_text) > 5000:
        content_text = content_text[:5000] + "\n... [truncated]"

    return f"<{tag}>\n{content_text}\n</{tag}>"


def _format_thinking(block: dict) -> str:
    """Format a thinking content block."""
    text = block.get("thinking", "")
    if not text:
        return ""
    if len(text) > 3000:
        text = text[:3000] + "\n... [truncated]"
    return f"<migrated_claude_code_thinking>\n{text}\n</migrated_claude_code_thinking>"


def _gen_id(prefix: str) -> str:
    """Generate a plausible OpenCode-style ID."""
    return f"{prefix}_{uuid.uuid4().hex[:24]}"


def convert_session(session_path: Path, title: str | None = None) -> dict:
    """Convert a Claude Code JSONL session to OpenCode export format."""
    lines = []
    with open(session_path) as f:
        for raw in f:
            lines.append(json.loads(raw))

    if not lines:
        print(f"Empty session: {session_path}", file=sys.stderr)
        sys.exit(1)

    # Extract metadata from first meaningful entry
    session_id = None
    cwd = None
    first_ts = None
    last_ts = None

    for obj in lines:
        if obj.get("sessionId"):
            session_id = obj["sessionId"]
        if obj.get("cwd") and not cwd:
            cwd = obj["cwd"]
        ts = obj.get("timestamp")
        if ts:
            if isinstance(ts, str):
                try:
                    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                    ts_ms = int(dt.timestamp() * 1000)
                except ValueError:
                    ts_ms = None
            elif isinstance(ts, (int, float)):
                ts_ms = int(ts)
            else:
                ts_ms = None

            if ts_ms:
                if first_ts is None or ts_ms < first_ts:
                    first_ts = ts_ms
                if last_ts is None or ts_ms > last_ts:
                    last_ts = ts_ms

    if not session_id:
        session_id = session_path.stem

    if not title:
        title = _get_session_title(session_path)
    if not title:
        title = f"Claude Code session {session_id[:8]}"
    # Truncate to first line, max 120 chars for readability in session picker
    title = title.split("\n")[0].strip()[:120]

    if not cwd:
        # Try to infer from the project directory name
        parent = session_path.parent.name
        cwd = decode_project_path(parent)

    now_ms = int(datetime.now(timezone.utc).timestamp() * 1000)
    oc_session_id = _gen_id("ses")

    # Build OpenCode messages from the JSONL entries
    messages = []
    for obj in lines:
        entry_type = obj.get("type")

        if entry_type == "user":
            msg = obj.get("message", {})
            content = msg.get("content", [])
            text_parts = []

            if isinstance(content, str):
                text_parts.append(content)
            elif isinstance(content, list):
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    btype = block.get("type")
                    if btype == "text":
                        text_parts.append(block["text"])
                    elif btype == "tool_result":
                        text_parts.append(_format_tool_result(block))

            if not text_parts:
                continue

            full_text = "\n\n".join(text_parts)
            msg_id = _gen_id("msg")
            messages.append({
                "info": {
                    "role": "user",
                    "time": {"created": _parse_ts(obj.get("timestamp")) or now_ms},
                    "id": msg_id,
                    "sessionID": oc_session_id,
                },
                "parts": [
                    {
                        "type": "text",
                        "text": full_text,
                        "id": _gen_id("prt"),
                        "sessionID": oc_session_id,
                        "messageID": msg_id,
                    }
                ],
            })

        elif entry_type == "assistant":
            msg = obj.get("message", {})
            content = msg.get("content", [])
            text_parts = []

            if isinstance(content, str):
                text_parts.append(content)
            elif isinstance(content, list):
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    btype = block.get("type")
                    if btype == "text":
                        text_parts.append(block["text"])
                    elif btype == "thinking":
                        formatted = _format_thinking(block)
                        if formatted:
                            text_parts.append(formatted)
                    elif btype == "tool_use":
                        text_parts.append(_format_tool_use(block))

            if not text_parts:
                continue

            full_text = "\n\n".join(text_parts)
            msg_id = _gen_id("msg")
            model_id = msg.get("model", "claude-sonnet-4-20250514")

            ts = _parse_ts(obj.get("timestamp")) or now_ms
            messages.append({
                "info": {
                    "role": "assistant",
                    "time": {
                        "created": ts,
                        "completed": ts,
                    },
                    "modelID": model_id,
                    "providerID": "anthropic",
                    "mode": "build",
                    "agent": "build",
                    "variant": "high",
                    "finish": "stop",
                    "cost": 0,
                    "path": {
                        "cwd": cwd or ".",
                        "root": cwd or ".",
                    },
                    "tokens": {
                        "total": 0,
                        "input": 0,
                        "output": 0,
                        "reasoning": 0,
                        "cache": {"read": 0, "write": 0},
                    },
                    "id": msg_id,
                    "sessionID": oc_session_id,
                },
                "parts": [
                    {
                        "type": "text",
                        "text": full_text,
                        "id": _gen_id("prt"),
                        "sessionID": oc_session_id,
                        "messageID": msg_id,
                    }
                ],
            })

    # Assemble the OpenCode export envelope
    return {
        "info": {
            "id": oc_session_id,
            "slug": f"claude-import-{session_id[:8]}",
            "projectID": "global",
            "directory": cwd or ".",
            "title": f"[Claude Code] {title}",
            "version": "imported",
            "summary": {"additions": 0, "deletions": 0, "files": 0},
            "time": {
                "created": first_ts or now_ms,
                "updated": last_ts or now_ms,
            },
        },
        "messages": messages,
    }


def _parse_ts(ts) -> int | None:
    """Parse a Claude Code timestamp (ISO string or epoch ms) to epoch ms."""
    if ts is None:
        return None
    if isinstance(ts, (int, float)):
        return int(ts)
    if isinstance(ts, str):
        try:
            dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
            return int(dt.timestamp() * 1000)
        except ValueError:
            return None
    return None


def main():
    parser = argparse.ArgumentParser(
        description="Convert Claude Code sessions to OpenCode import format"
    )
    parser.add_argument("session", nargs="?", help="Path to Claude Code .jsonl session file")
    parser.add_argument("--title", help="Override session title")
    parser.add_argument("--list", action="store_true", help="List available Claude Code sessions")
    parser.add_argument("--project", help="Filter by project path substring")
    parser.add_argument("--all", action="store_true", help="Convert all sessions for a project")
    parser.add_argument("--out-dir", default="/tmp/claude-to-opencode", help="Output directory for --all mode")
    args = parser.parse_args()

    if args.list:
        list_sessions(args.project)
        return

    if args.all:
        if not args.project:
            print("--all requires --project <path-substring>", file=sys.stderr)
            sys.exit(1)
        out_dir = Path(args.out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        count = 0
        for project_dir in sorted(PROJECTS_DIR.iterdir()):
            if not project_dir.is_dir():
                continue
            project_path = decode_project_path(project_dir.name)
            if args.project not in project_path:
                continue
            for session_file in project_dir.glob("*.jsonl"):
                try:
                    result = convert_session(session_file, args.title)
                    out_file = out_dir / f"{session_file.stem}.json"
                    with open(out_file, "w") as f:
                        json.dump(result, f, indent=2)
                    count += 1
                    print(f"Converted: {session_file.stem} -> {out_file}", file=sys.stderr)
                except Exception as e:
                    print(f"Skipped {session_file.stem}: {e}", file=sys.stderr)
        print(f"\nConverted {count} sessions to {out_dir}/", file=sys.stderr)
        print(f"Import with: for f in {out_dir}/*.json; do opencode import \"$f\"; done", file=sys.stderr)
        return

    if not args.session:
        parser.print_help()
        sys.exit(1)

    session_path = Path(args.session)
    if not session_path.exists():
        # Try interpreting as a session ID within the projects dir
        matches = list(PROJECTS_DIR.rglob(f"{args.session}.jsonl"))
        if matches:
            session_path = matches[0]
        else:
            print(f"Session not found: {args.session}", file=sys.stderr)
            sys.exit(1)

    result = convert_session(session_path, args.title)
    json.dump(result, sys.stdout, indent=2)
    print()  # trailing newline


if __name__ == "__main__":
    main()
