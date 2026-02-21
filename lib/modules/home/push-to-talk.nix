{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.lyte.push-to-talk;

  whisper-cpp = pkgs.whisper-cpp-vulkan;

  python = pkgs.python3.withPackages (ps: [ ps.evdev ]);

  daemon = pkgs.writeScriptBin "push-to-talk-daemon" ''
    #!${python}/bin/python3
    """
    Push-to-talk voice typing daemon.

    Monitors keyboard via evdev for Super+V hold/release.
    On hold: starts recording via pw-record.
    On release: stops recording, transcribes with whisper-cpp, types with wtype.
    """

    import os
    import sys
    import glob
    import signal
    import select
    import subprocess
    import tempfile
    import time
    import evdev
    from evdev import ecodes

    MODEL_NAME = os.environ.get("PUSH_TO_TALK_MODEL", "${cfg.model}")
    MODEL_DIR = os.path.expanduser("~/.local/share/whisper")
    MODEL_PATH = os.path.join(MODEL_DIR, f"ggml-{MODEL_NAME}.bin")

    WHISPER_CMD = "${whisper-cpp}/bin/whisper-cli"
    WTYPE_CMD = "${pkgs.wtype}/bin/wtype"
    YDOTOOL_CMD = "${pkgs.ydotool}/bin/ydotool"
    PWRECORD_CMD = "${pkgs.pipewire}/bin/pw-record"
    NOTIFY_CMD = "${pkgs.libnotify}/bin/notify-send"

    # Key codes
    KEY_LEFTMETA = ecodes.KEY_LEFTMETA
    KEY_RIGHTMETA = ecodes.KEY_RIGHTMETA
    KEY_V = ecodes.KEY_V

    class PushToTalk:
        def __init__(self):
            self.super_held = False
            self.recording = False
            self.record_proc = None
            self.tmp_wav = None
            self.devices = {}
            self.check_model()
            self.scan_devices()

        def check_model(self):
            if not os.path.isfile(MODEL_PATH):
                self.notify("Push-to-Talk", f"Model not found: {MODEL_PATH}\nRun: push-to-talk-download-model {MODEL_NAME}", urgency="critical")
                print(f"WARNING: Model not found at {MODEL_PATH}", file=sys.stderr)
                print(f"Run: push-to-talk-download-model {MODEL_NAME}", file=sys.stderr)

        def notify(self, title, body, urgency="normal", replace_id=None):
            cmd = [NOTIFY_CMD, "-a", "push-to-talk", "-u", urgency]
            if replace_id:
                cmd.extend(["-h", f"string:x-dunst-stack-tag:{replace_id}"])
                cmd.extend(["-h", f"string:x-niri-stack-tag:{replace_id}"])
            cmd.extend([title, body])
            try:
                subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                pass

        def scan_devices(self):
            """Find all keyboard input devices."""
            old_paths = set(self.devices.keys())
            new_paths = set()
            for path in sorted(glob.glob("/dev/input/event*")):
                new_paths.add(path)
                if path not in self.devices:
                    try:
                        dev = evdev.InputDevice(path)
                        caps = dev.capabilities()
                        # Only grab devices that have EV_KEY with at least KEY_V
                        if ecodes.EV_KEY in caps and KEY_V in caps[ecodes.EV_KEY]:
                            self.devices[path] = dev
                            print(f"Monitoring: {dev.name} ({path})", file=sys.stderr)
                        else:
                            dev.close()
                    except (PermissionError, OSError) as e:
                        pass

            # Remove devices that disappeared
            for path in old_paths - new_paths:
                if path in self.devices:
                    try:
                        self.devices[path].close()
                    except Exception:
                        pass
                    del self.devices[path]
                    print(f"Removed: {path}", file=sys.stderr)

        def start_recording(self):
            if self.recording:
                return
            if not os.path.isfile(MODEL_PATH):
                self.notify("Push-to-Talk", "Model not downloaded. Run push-to-talk-download-model", urgency="critical", replace_id="ptt")
                return

            fd, self.tmp_wav = tempfile.mkstemp(suffix=".wav", prefix="ptt-")
            os.close(fd)
            try:
                self.record_proc = subprocess.Popen(
                    [PWRECORD_CMD, "--rate=16000", "--channels=1", "--format=s16", self.tmp_wav],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                self.recording = True
                print("Recording started", file=sys.stderr)
            except Exception as e:
                print(f"Failed to start recording: {e}", file=sys.stderr)
                self.notify("Push-to-Talk", f"Recording failed: {e}", urgency="critical", replace_id="ptt")

        def stop_recording_and_transcribe(self):
            if not self.recording:
                return
            self.recording = False

            # Stop pw-record
            if self.record_proc:
                self.record_proc.send_signal(signal.SIGINT)
                try:
                    self.record_proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.record_proc.kill()
                    self.record_proc.wait()
                self.record_proc = None

            wav_path = self.tmp_wav
            self.tmp_wav = None

            if not wav_path or not os.path.isfile(wav_path):
                print("No recording file found", file=sys.stderr)
                return

            # Check file size (skip if too small = no audio)
            if os.path.getsize(wav_path) < 1000:
                print("Recording too short, skipping", file=sys.stderr)
                os.unlink(wav_path)
                return

            print("Transcribing...", file=sys.stderr)

            try:
                result = subprocess.run(
                    [WHISPER_CMD, "-m", MODEL_PATH, "-f", wav_path, "-np", "-nt"],
                    capture_output=True,
                    text=True,
                    timeout=30,
                )
                text = result.stdout.strip()

                # Clean up common whisper artifacts
                if text.startswith("["):
                    # Remove timestamp prefix like [00:00:00.000 --> 00:00:02.000]
                    lines = text.split("\n")
                    cleaned = []
                    for line in lines:
                        line = line.strip()
                        if line.startswith("[") and "]" in line:
                            line = line[line.index("]") + 1:].strip()
                        if line:
                            cleaned.append(line)
                    text = " ".join(cleaned)

                # Filter out common whisper hallucinations on silence
                hallucinations = {
                    "(silence)", "[silence]", "(blank audio)", "[blank audio]",
                    "(no speech)", "[no speech]", "(inaudible)", "[inaudible]",
                    "you", "thank you.", "thanks for watching!",
                    "(buzzing)", "[buzzing]", "(static)", "[static]",
                }
                if text.lower().strip("., ") in hallucinations or not text.strip():
                    print(f"Empty or hallucinated transcription: {text!r}", file=sys.stderr)
                    os.unlink(wav_path)
                    return

                print(f"Transcribed: {text}", file=sys.stderr)

                # Type the result (try wtype first, fall back to ydotool)
                try:
                    result = subprocess.run(
                        [WTYPE_CMD, "--", text],
                        timeout=10,
                        capture_output=True,
                    )
                    if result.returncode != 0:
                        raise RuntimeError(result.stderr.decode().strip())
                except Exception as wtype_err:
                    print(f"wtype failed ({wtype_err}), trying ydotool", file=sys.stderr)
                    subprocess.run(
                        [YDOTOOL_CMD, "type", "--key-delay=0", "--key-hold=0", "--", text],
                        timeout=10,
                    )

            except subprocess.TimeoutExpired:
                print("Transcription timed out", file=sys.stderr)
                self.notify("Push-to-Talk", "Transcription timed out", urgency="critical", replace_id="ptt")
            except Exception as e:
                print(f"Transcription error: {e}", file=sys.stderr)
                self.notify("Push-to-Talk", f"Error: {e}", urgency="critical", replace_id="ptt")
            finally:
                if os.path.isfile(wav_path):
                    os.unlink(wav_path)

        def handle_event(self, event):
            if event.type != ecodes.EV_KEY:
                return

            # Track Super modifier
            if event.code in (KEY_LEFTMETA, KEY_RIGHTMETA):
                if event.value == 1:  # key down
                    self.super_held = True
                elif event.value == 0:  # key up
                    self.super_held = False
                    # If recording and super released, also stop
                    if self.recording:
                        self.stop_recording_and_transcribe()

            # Track V key while Super is held
            elif event.code == KEY_V:
                if event.value == 1 and self.super_held:  # V key down while Super held
                    self.start_recording()
                elif event.value == 0 and self.recording:  # V key up while recording
                    self.stop_recording_and_transcribe()

        def run(self):
            print("Push-to-talk daemon started", file=sys.stderr)
            rescan_interval = 10  # seconds
            last_scan = time.time()

            while True:
                if not self.devices:
                    self.scan_devices()
                    if not self.devices:
                        time.sleep(2)
                        continue

                # Build fd list for select
                try:
                    fds = {dev.fd: dev for dev in self.devices.values()}
                    readable, _, _ = select.select(fds.keys(), [], [], 1.0)
                except (ValueError, OSError):
                    # Device removed during select
                    self.scan_devices()
                    continue

                for fd in readable:
                    dev = fds.get(fd)
                    if dev is None:
                        continue
                    try:
                        for event in dev.read():
                            self.handle_event(event)
                    except OSError:
                        # Device disconnected
                        path = dev.path
                        print(f"Device disconnected: {path}", file=sys.stderr)
                        try:
                            dev.close()
                        except Exception:
                            pass
                        if path in self.devices:
                            del self.devices[path]

                # Periodic rescan for new devices
                now = time.time()
                if now - last_scan > rescan_interval:
                    self.scan_devices()
                    last_scan = now

    if __name__ == "__main__":
        ptt = PushToTalk()
        ptt.run()
  '';

  downloadScript = pkgs.writeShellScriptBin "push-to-talk-download-model" ''
    set -euo pipefail

    MODEL="''${1:-${cfg.model}}"
    MODEL_DIR="$HOME/.local/share/whisper"
    MODEL_FILE="$MODEL_DIR/ggml-$MODEL.bin"
    BASE_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

    mkdir -p "$MODEL_DIR"

    if [ -f "$MODEL_FILE" ]; then
      echo "Model already exists: $MODEL_FILE"
      echo "Delete it first if you want to re-download."
      exit 0
    fi

    echo "Downloading ggml-$MODEL.bin to $MODEL_DIR..."
    ${pkgs.curl}/bin/curl -L --progress-bar \
      "$BASE_URL/ggml-$MODEL.bin" \
      -o "$MODEL_FILE.part"

    mv "$MODEL_FILE.part" "$MODEL_FILE"
    echo "Downloaded: $MODEL_FILE"
    echo "Model ready for push-to-talk."
  '';
in
{
  options.lyte.push-to-talk = {
    enable = lib.mkEnableOption "push-to-talk voice typing via whisper-cpp";
    model = lib.mkOption {
      type = lib.types.str;
      default = "base.en";
      description = "Whisper model name (e.g. base.en, tiny.en, small.en)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      daemon
      downloadScript
      whisper-cpp
      pkgs.wtype
      pkgs.ydotool
    ];

    # Unbind Super+V in GNOME (opens notification tray by default)
    dconf.settings."org/gnome/shell/keybindings".toggle-message-tray = [ ];

    systemd.user.services.push-to-talk-download-model = {
      Unit = {
        Description = "Download whisper model for push-to-talk";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${downloadScript}/bin/push-to-talk-download-model ${cfg.model}";
        ExecStartPost = "${pkgs.systemd}/bin/systemctl --user try-restart push-to-talk.service";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    systemd.user.services.ydotoold = {
      Unit = {
        Description = "ydotool daemon for virtual input";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.ydotool}/bin/ydotoold";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    systemd.user.services.push-to-talk = {
      Unit = {
        Description = "Push-to-talk voice typing daemon";
        After = [
          "graphical-session-pre.target"
          "ydotoold.service"
        ];
        Wants = [ "ydotoold.service" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${daemon}/bin/push-to-talk-daemon";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
