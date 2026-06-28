{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.lyte.tv-player;

  # Token-authed HTTP control service. Launches mpv fullscreen into the desktop
  # user's live graphical session (Wayland env auto-discovered from a running
  # session process), so "play X on the TV" from Home Assistant lands a video on
  # the screen over the Firefox/Hearth kiosk; quitting mpv drops back to it.
  server = pkgs.writeText "tv-player.py" ''
    import http.server, json, os, subprocess, glob, urllib.parse, socket, pwd, shlex

    USER = os.environ.get("TV_PLAYER_USER", "daniel")
    PORT = int(os.environ.get("TV_PLAYER_PORT", "8730"))
    PATH_EXTRA = os.environ.get("TV_PLAYER_PATH", "/run/current-system/sw/bin")
    TOKEN = open(os.environ["TV_PLAYER_TOKEN_FILE"]).read().strip()
    SOCK = "/run/tv-player/mpv.sock"
    PW = pwd.getpwnam(USER); UID = PW.pw_uid; HOME = PW.pw_dir

    def session_env():
        env = {"XDG_RUNTIME_DIR": "/run/user/%d" % UID, "WAYLAND_DISPLAY": "wayland-0",
               "DBUS_SESSION_BUS_ADDRESS": "unix:path=/run/user/%d/bus" % UID}
        for envf in glob.glob("/proc/[0-9]*/environ"):
            try:
                pid = envf.split("/")[2]
                if os.stat("/proc/%s" % pid).st_uid != UID: continue
                d = {}
                for kv in open(envf, "rb").read().split(b"\0"):
                    if b"=" in kv:
                        k, v = kv.split(b"=", 1); d[k.decode()] = v.decode("utf-8", "replace")
                if "WAYLAND_DISPLAY" in d:
                    for k in ("WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "DBUS_SESSION_BUS_ADDRESS", "DISPLAY"):
                        if k in d: env[k] = d[k]
                    break
            except Exception:
                continue
        return env

    def kill_mpv():
        subprocess.run(["pkill", "-u", USER, "-x", "mpv"])

    def launch(media):
        kill_mpv()
        os.makedirs("/run/tv-player", exist_ok=True)
        try: os.remove(SOCK)
        except FileNotFoundError: pass
        # Use a login shell (runuser -l) so HOME/PATH are set correctly for the
        # user; -u without a login shell left HOME=/root and mpv tripped on
        # /root/.cache. `env VAR=...` then injects the live session display vars.
        env = session_env()
        prefix = " ".join("%s=%s" % (k, shlex.quote(v)) for k, v in env.items())
        mpv = ("mpv --fullscreen --force-window=immediate --no-terminal "
               "--ytdl-format=%s --input-ipc-server=%s %s") % (
            shlex.quote("bestvideo[height<=?1080]+bestaudio/best"),
            shlex.quote(SOCK), shlex.quote(media))
        cmd = ["runuser", "-l", USER, "-c", "env %s %s" % (prefix, mpv)]
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def ipc(command):
        try:
            s = socket.socket(socket.AF_UNIX); s.connect(SOCK)
            s.sendall((json.dumps({"command": command}) + "\n").encode()); s.close()
        except Exception:
            pass

    class H(http.server.BaseHTTPRequestHandler):
        def _ok(self):
            return self.headers.get("Authorization", "") == "Bearer " + TOKEN
        def do_POST(self):
            if not self._ok():
                self.send_response(401); self.end_headers(); return
            n = int(self.headers.get("Content-Length", "0") or 0)
            try: body = json.loads(self.rfile.read(n) or b"{}")
            except Exception: body = {}
            p = urllib.parse.urlparse(self.path).path
            if p == "/play":
                src = body.get("source", "youtube"); q = (body.get("query") or "").strip()
                media = ("ytdl://ytsearch:" + q) if src == "youtube" else q
                if q: launch(media)
            elif p == "/stop": kill_mpv()
            elif p == "/pause": ipc(["set_property", "pause", True])
            elif p == "/resume": ipc(["set_property", "pause", False])
            self.send_response(200); self.send_header("Content-Type", "application/json"); self.end_headers()
            self.wfile.write(b'{"ok":true}')
        def log_message(self, *a): pass

    http.server.HTTPServer(("0.0.0.0", PORT), H).serve_forever()
  '';
in
{
  options.lyte.tv-player = {
    enable = lib.mkEnableOption "TV video player (mpv) control service for Home Assistant";
    user = lib.mkOption {
      type = lib.types.str;
      default = config.lyte.username;
      description = "Desktop user whose graphical session mpv is launched into.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8730;
      description = "Control HTTP port (token-authed).";
    };
    tokenFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the bearer token shared with Home Assistant.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.mpv pkgs.yt-dlp ];

    systemd.services.tv-player = {
      description = "TV video player control service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ pkgs.util-linux pkgs.procps ]; # runuser + pkill
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 ${server}";
        Restart = "on-failure";
        RestartSec = 5;
        RuntimeDirectory = "tv-player";
        Environment = [
          "TV_PLAYER_PORT=${toString cfg.port}"
          "TV_PLAYER_USER=${cfg.user}"
          "TV_PLAYER_TOKEN_FILE=${cfg.tokenFile}"
          "TV_PLAYER_PATH=/run/current-system/sw/bin"
        ];
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
