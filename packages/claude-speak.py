#!/usr/bin/env python3
"""claude-speak: read Claude Code assistant messages aloud, fully locally.

Tails a Claude Code session JSONL log (~/.claude/projects/<slug>/<session>.jsonl),
extracts new assistant text messages, cleans them for speech, synthesizes with
Piper (offline neural TTS), and plays through PipeWire (pw-play).

No hooks, no MCP, no network TTS.

Usage:
  claude-speak                          # foreground: follow latest session for $PWD's project
  claude-speak --jsonl FILE             # foreground: follow one specific session file
  claude-speak --follow-latest DIR      # foreground: follow latest session jsonl in DIR
  claude-speak on [--jsonl FILE]        # start a background monitor (for /speak)
  claude-speak off [--jsonl FILE]       # stop the background monitor
  claude-speak status [--jsonl FILE]    # is a monitor running?
  claude-speak --speak "text"           # one-shot: speak a string and exit
"""

import argparse
import glob
import hashlib
import json
import os
import queue
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time

DEFAULT_MODEL = os.environ.get(
    "CLAUDE_SPEAK_MODEL",
    os.path.expanduser("~/.local/share/piper-voices/en_US-lessac-medium.onnx"),
)
CLAUDE_PROJECTS = os.path.expanduser("~/.claude/projects")
RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", tempfile.gettempdir())


def project_dir_for_cwd(cwd):
    """Claude Code encodes a project cwd by replacing non-alphanumerics with '-'."""
    slug = re.sub(r"[^A-Za-z0-9]", "-", os.path.abspath(cwd))
    return os.path.join(CLAUDE_PROJECTS, slug)


def latest_jsonl(directory):
    files = glob.glob(os.path.join(directory, "*.jsonl"))
    return max(files, key=os.path.getmtime) if files else None


# --- text cleaning (subset of upstream claude-speak's clean_text) -----------

RE_FENCED_CODE = re.compile(r"```[^\n]*\n.*?```", re.DOTALL)
RE_INLINE_CODE = re.compile(r"`([^`]+)`")
RE_MD_IMAGE = re.compile(r"!\[[^\]]*\]\([^)]+\)")
RE_MD_LINK = re.compile(r"\[([^\]]+)\]\([^)]+\)")
RE_MD_EMPH = re.compile(r"\*{1,3}([^*]+)\*{1,3}")
RE_MD_HEADER = re.compile(r"^#{1,6}\s+", re.MULTILINE)
RE_MD_BULLET = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+", re.MULTILINE)
RE_URL = re.compile(r"https?://\S+")
RE_PATH = re.compile(r"(?:^|\s)(?:[/\\][\w.@-]+){2,}(?::\d+)?", re.MULTILINE)
RE_HTML_TAG = re.compile(r"<[^>]+>")
RE_TABLE_ROW = re.compile(r"^\s*\|.*\|\s*$", re.MULTILINE)
RE_HRULE = re.compile(r"^[\s]*[-=_*]{3,}[\s]*$", re.MULTILINE)


def clean_text(text):
    text = RE_FENCED_CODE.sub(" code block. ", text)
    text = RE_INLINE_CODE.sub(r"\1", text)
    text = RE_MD_IMAGE.sub("", text)
    text = RE_MD_LINK.sub(r"\1", text)
    text = RE_MD_EMPH.sub(r"\1", text)
    text = RE_MD_HEADER.sub("", text)
    text = RE_TABLE_ROW.sub("", text)
    text = RE_HRULE.sub("", text)
    text = RE_MD_BULLET.sub("", text)
    text = RE_URL.sub(" URL ", text)
    text = RE_PATH.sub(" path ", text)
    text = RE_HTML_TAG.sub("", text)
    text = text.replace("->", " to ").replace("=>", " to ").replace("&", " and ")
    text = re.sub(r"\b(\w+)_(\w+)\b", lambda m: m.group(0).replace("_", " "), text)
    text = re.sub(r"[{}\[\]|~^#]", " ", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r"\n\s*\n+", "\n", text)
    return text.strip()


def extract_assistant_text(line):
    """Return (text, message_id) for an assistant JSONL line, else (None, None)."""
    try:
        data = json.loads(line)
    except ValueError:
        return None, None
    if data.get("type") != "assistant":
        return None, None
    message = data.get("message") or {}
    parts = [
        b.get("text", "")
        for b in message.get("content") or []
        if isinstance(b, dict) and b.get("type") == "text" and b.get("text", "").strip()
    ]
    if not parts:
        return None, None
    return " ".join(parts), message.get("id") or data.get("uuid")


# --- TTS + playback ----------------------------------------------------------


def find_player():
    for candidate in (
        ["pw-play"],
        ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet"],
        ["paplay"],
        ["aplay", "-q"],
    ):
        if shutil.which(candidate[0]):
            return candidate
    sys.exit("claude-speak: no audio player found (need pw-play, ffplay, paplay, or aplay)")


class Speaker:
    """Serialized speech queue: synthesize with piper, play, one at a time."""

    def __init__(self, model, rate):
        self.model = model
        self.length_scale = str(1.0 / rate)
        self.player = find_player()
        self.tmpdir = tempfile.mkdtemp(prefix="claude-speak-")
        self.q = queue.Queue()
        self.counter = 0
        threading.Thread(target=self._worker, daemon=True).start()

    def say(self, text):
        cleaned = clean_text(text)
        if len(cleaned.split()) >= 3:
            self.q.put(cleaned)

    def _worker(self):
        while True:
            text = self.q.get()
            self.counter += 1
            wav = os.path.join(self.tmpdir, f"{self.counter}.wav")
            try:
                subprocess.run(
                    ["piper", "-m", self.model, "--length-scale", self.length_scale, "-f", wav],
                    input=text.encode(),
                    check=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                subprocess.run(
                    self.player + [wav],
                    check=False,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            except (subprocess.CalledProcessError, OSError) as e:
                print(f"claude-speak: tts/playback error: {e}", file=sys.stderr)
            finally:
                try:
                    os.remove(wav)
                except OSError:
                    pass
                self.q.task_done()

    def cleanup(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)


# --- monitor -----------------------------------------------------------------


def follow(jsonl_path_fn, speaker, debounce_ms, from_start):
    """Tail whichever jsonl jsonl_path_fn() currently returns; speak new assistant messages."""
    current = None
    pos = 0
    spoken = {}  # message_id -> True (bounded)
    pending = {}  # message_id -> (text, last_seen_time); debounce for streamed messages
    last_rescan = 0.0

    while True:
        now = time.time()
        if now - last_rescan > 5 or current is None:
            last_rescan = now
            latest = jsonl_path_fn()
            if latest and latest != current:
                current = latest
                pos = 0 if from_start else os.path.getsize(current)
                print(f"claude-speak: following {current}", file=sys.stderr)

        if current and os.path.exists(current):
            try:
                size = os.path.getsize(current)
                if size < pos:
                    pos = size
                elif size > pos:
                    with open(current, encoding="utf-8") as f:
                        f.seek(pos)
                        chunk = f.read()
                        pos = f.tell()
                    for line in chunk.splitlines():
                        text, mid = extract_assistant_text(line.strip())
                        if text and mid not in spoken:
                            # streamed messages repeat the same id with growing
                            # text; keep the latest version and debounce
                            pending[mid] = (text, now)
            except OSError:
                pass

        for mid, (text, seen) in list(pending.items()):
            if (now - seen) * 1000 >= debounce_ms:
                del pending[mid]
                spoken[mid] = True
                if len(spoken) > 2000:
                    for k in list(spoken)[:1000]:
                        del spoken[k]
                speaker.say(text)

        time.sleep(0.5)


# --- background daemon control (used by the /speak slash command) ------------


def pid_file_for(target):
    """One pidfile per monitored target (session file or project dir)."""
    digest = hashlib.sha256(target.encode()).hexdigest()[:12]
    return os.path.join(RUNTIME_DIR, f"claude-speak-{digest}.pid")


def daemon_pid(target):
    """Return the running monitor's pid for target, or None."""
    try:
        with open(pid_file_for(target)) as f:
            pid = int(f.read().strip())
        os.kill(pid, 0)
        return pid
    except (OSError, ValueError):
        return None


def daemonize(target):
    """Double-fork so the monitor survives its parent (e.g. a Claude Bash call)."""
    if os.fork() > 0:
        os._exit(0)
    os.setsid()
    if os.fork() > 0:
        os._exit(0)
    devnull = os.open(os.devnull, os.O_RDWR)
    for fd in (0, 1, 2):
        os.dup2(devnull, fd)
    with open(pid_file_for(target), "w") as f:
        f.write(str(os.getpid()))


def cmd_on(target, jsonl_fn, speaker_args, debounce):
    pid = daemon_pid(target)
    if pid:
        print(f"claude-speak: already running (pid {pid}) for {target}")
        return
    # flush before daemonize: the parent exits with os._exit, which drops buffers
    print(f"claude-speak: monitor started for {target}", flush=True)
    daemonize(target)
    speaker = Speaker(*speaker_args)
    try:
        follow(jsonl_fn, speaker, debounce, from_start=False)
    finally:
        speaker.cleanup()
        try:
            os.remove(pid_file_for(target))
        except OSError:
            pass


def cmd_off(target):
    pid = daemon_pid(target)
    if not pid:
        print(f"claude-speak: no monitor running for {target}")
        return
    os.kill(pid, signal.SIGTERM)
    try:
        os.remove(pid_file_for(target))
    except OSError:
        pass
    print(f"claude-speak: stopped monitor (pid {pid}) for {target}")


def cmd_status(target):
    pid = daemon_pid(target)
    if pid:
        print(f"claude-speak: running (pid {pid}) for {target}")
    else:
        print(f"claude-speak: not running for {target}")


def main():
    ap = argparse.ArgumentParser(
        description="Speak Claude Code assistant messages via Piper (local TTS)"
    )
    ap.add_argument(
        "command",
        nargs="?",
        choices=["on", "off", "status"],
        help="control a background monitor; omit to run in the foreground",
    )
    scope = ap.add_mutually_exclusive_group()
    scope.add_argument("--jsonl", help="follow one specific session jsonl file")
    scope.add_argument(
        "--follow-latest",
        metavar="DIR",
        help="follow latest session jsonl in DIR (default: this project's dir)",
    )
    scope.add_argument("--speak", metavar="TEXT", help="one-shot: speak TEXT and exit")
    ap.add_argument("--model", default=DEFAULT_MODEL, help="piper voice model (.onnx)")
    ap.add_argument(
        "--rate",
        type=float,
        default=float(os.environ.get("CLAUDE_SPEAK_RATE", "1.0")),
        help="speech speed multiplier (1.0 normal, 1.2 faster)",
    )
    ap.add_argument("--debounce", type=int, default=1500, help="ms to let a message settle")
    ap.add_argument("--from-start", action="store_true", help="speak existing log content too")
    args = ap.parse_args()

    if not os.path.exists(args.model):
        sys.exit(
            f"claude-speak: piper voice model not found: {args.model}\n"
            "Download one from https://huggingface.co/rhasspy/piper-voices"
        )

    if args.speak is not None:
        speaker = Speaker(args.model, args.rate)
        speaker.say(args.speak)
        speaker.q.join()
        speaker.cleanup()
        return

    if args.jsonl:
        target = os.path.abspath(args.jsonl)
        jsonl_fn = lambda: target if os.path.exists(target) else None
    else:
        target = os.path.abspath(args.follow_latest or project_dir_for_cwd(os.getcwd()))
        if not os.path.isdir(target):
            sys.exit(f"claude-speak: no such project dir: {target}")
        jsonl_fn = lambda: latest_jsonl(target)

    if args.command == "off":
        cmd_off(target)
        return
    if args.command == "status":
        cmd_status(target)
        return
    if args.command == "on":
        cmd_on(target, jsonl_fn, (args.model, args.rate), args.debounce)
        return

    speaker = Speaker(args.model, args.rate)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        follow(jsonl_fn, speaker, args.debounce, args.from_start)
    except KeyboardInterrupt:
        pass
    finally:
        speaker.cleanup()


if __name__ == "__main__":
    main()
