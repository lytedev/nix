{
  pkgs,
  ...
}:
pkgs.writeShellApplication {
  name = "text-to-mic";
  runtimeInputs = with pkgs; [
    piper-tts
    pipewire
    coreutils
  ];
  text = ''
    VIRTUAL_MIC="TextToMic"

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

    cleanup() {
      echo ""
      echo "Cleaning up virtual mic..."
      pw-cli destroy "$VIRTUAL_MIC" 2>/dev/null || true
    }
    trap cleanup EXIT

    # Create a virtual audio source (microphone) via PipeWire
    echo "Creating virtual microphone '$VIRTUAL_MIC'..."
    pw-cli create-node adapter "{
      factory.name=support.null-audio-sink
      node.name=$VIRTUAL_MIC
      media.class=Audio/Source/Virtual
      audio.position=[FL FR]
      monitor.channel-volumes=true
      monitor.passthrough=true
    }" >/dev/null

    sleep 0.5

    echo ""
    echo "Virtual microphone '$VIRTUAL_MIC' is active."
    echo "Set your meeting app's mic input to '$VIRTUAL_MIC'."
    echo ""
    echo "Type text and press Enter to speak. Ctrl-D or Ctrl-C to quit."
    echo ""

    while IFS= read -r -p "> " line; do
      [ -z "$line" ] && continue
      # Generate speech, tee to both default output and virtual mic
      echo "$line" | piper-tts --model "$MODEL" --output_raw 2>/dev/null | \
        tee >(pw-play --target "$VIRTUAL_MIC" --rate 22050 --channels 1 --format s16 -) | \
        pw-play --rate 22050 --channels 1 --format s16 -
    done
  '';
}
