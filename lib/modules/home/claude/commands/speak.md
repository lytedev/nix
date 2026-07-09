---
description: Toggle reading responses aloud via local TTS (piper)
allowed-tools: Bash(claude-speak:*), Bash(ls:*)
---

# /speak — read my responses aloud (local Piper TTS)

`$ARGUMENTS` is one of: `on` (default when empty), `off`, `status`.

## Steps

1. Pin THIS session's log file. The current session is the most recently
   modified jsonl in this project's log directory (this prompt was just
   written to it):

   ```bash
   ls -t ~/.claude/projects/<cwd-with-non-alphanumerics-replaced-by-dashes>/*.jsonl | head -1
   ```

2. Run the requested action against that exact file:

   ```bash
   claude-speak on --jsonl <session-file>      # or: off / status
   ```

   The monitor daemonizes and survives this command; `off` stops it.

3. Report the result (running / stopped / status) to the user in one short
   sentence.

## Behavior while speech is ON — follow strictly for every later message

- Your messages are being read aloud by a text-to-speech engine. Be
  thoughtful about output: lead with a short, spoken-friendly summary in
  plain prose; prefer sentences over tables, symbols, long paths, and
  identifier soup. Code blocks are stripped before speaking, so never put
  essential information only inside one.
- Begin EVERY message with the exact line `Claude Message Incoming.` on its
  own line, so the user knows to start listening before the content arrives.

When speech is turned OFF (or `claude-speak off` is run), stop prefixing and
return to normal output style.
