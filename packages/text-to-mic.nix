{
  pkgs,
  ...
}:
pkgs.writeShellApplication {
  name = "text-to-mic";
  runtimeInputs = with pkgs; [
    piper-tts
    pipewire
    pulseaudio
    coreutils
  ];
  text = ''
    SINK_NAME="TextToMic"

    # Check for a piper voice model
    MODEL_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/piper-voices"
    MODEL="$MODEL_DIR/en_US-lessac-medium.onnx"
    MODEL_JSON="$MODEL.json"

    if [ ! -f "$MODEL" ]; then
      echo "Downloading piper voice model..."
      mkdir -p "$MODEL_DIR"
      ${pkgs.curl}/bin/curl -sL "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx" -o "$MODEL"
      ${pkgs.curl}/bin/curl -sL "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json" -o "$MODEL_JSON"
    fi

    MODULE_ID=""
    cleanup() {
      echo ""
      echo "Cleaning up virtual mic..."
      if [ -n "$MODULE_ID" ]; then
        pactl unload-module "$MODULE_ID" 2>/dev/null || true
      fi
    }
    trap cleanup EXIT

    # Create a null sink via PulseAudio — its monitor appears as a mic input
    echo "Creating virtual microphone '$SINK_NAME'..."
    MODULE_ID=$(pactl load-module module-null-sink sink_name="$SINK_NAME" \
      sink_properties=device.description="$SINK_NAME")

    echo ""
    echo "Virtual microphone active."
    echo "Set your meeting app's mic input to 'Monitor of $SINK_NAME'."
    echo ""
    echo "Type text and press Enter to speak. Ctrl-D or Ctrl-C to quit."
    echo ""

    while IFS= read -r -p "> " line; do
      [ -z "$line" ] && continue
      # Generate speech to a temp file (piper needs a file or stdout)
      TMPWAV=$(mktemp --suffix=.wav)
      echo "$line" | piper-tts --model "$MODEL" --output_file "$TMPWAV" 2>/dev/null
      # Play to both the virtual sink (for meeting apps) and default output
      pw-play --target "$SINK_NAME" "$TMPWAV" &
      pw-play "$TMPWAV"
      wait
      rm -f "$TMPWAV"
    done
  '';
}
