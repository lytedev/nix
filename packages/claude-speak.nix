{
  pkgs,
  ...
}:
# Read Claude Code assistant messages aloud with fully-local TTS (piper).
# Tails the session JSONL logs under ~/.claude/projects/ — no hooks, no MCP,
# and no network TTS (unlike upstream claude-speak, which ships every message
# to Microsoft via edge-tts). Toggled per-session with the /speak command.
pkgs.writeShellApplication {
  name = "claude-speak";
  runtimeInputs = with pkgs; [
    piper-tts
    pipewire
    python3
  ];
  text = ''
    # Same lazily-downloaded voice model convention as text-to-mic
    MODEL_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/piper-voices"
    MODEL="$MODEL_DIR/en_US-lessac-medium.onnx"

    if [ ! -f "$MODEL" ]; then
      echo "Downloading piper voice model..." >&2
      mkdir -p "$MODEL_DIR"
      ${pkgs.curl}/bin/curl -sL "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx" -o "$MODEL"
      ${pkgs.curl}/bin/curl -sL "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json" -o "$MODEL.json"
    fi

    export CLAUDE_SPEAK_MODEL="''${CLAUDE_SPEAK_MODEL:-$MODEL}"
    exec python3 ${./claude-speak.py} "$@"
  '';
}
