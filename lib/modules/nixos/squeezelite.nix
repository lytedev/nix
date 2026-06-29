{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.lyte.squeezelite;
in
{
  options.lyte.squeezelite = {
    enable = lib.mkEnableOption "Squeezelite player for Music Assistant multi-room audio";

    server = lib.mkOption {
      type = lib.types.str;
      # Stable mDNS name (resolves to beefcake's LAN IPv4) rather than a raw IP
      # that breaks when MA moves hosts — which is exactly what happened moving
      # off bigtower. Use .local (avahi → LAN IPv4), NOT .lan (resolves to a
      # public IPv6 that MA's IPv4-only SlimProto doesn't bind).
      default = "beefcake.local";
      description = ''
        Music Assistant SlimProto server address (the host running Music
        Assistant with its `squeezelite` provider enabled). Optionally
        `host:port`; SlimProto defaults to port 3483.
      '';
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Player name shown in Music Assistant.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Run squeezelite inside the user's graphical session (a systemd *user*
    # service) so it shares that session's PipeWire and outputs to whatever
    # sink is currently active — i.e. HDMI/the TV when the deck is docked.
    # The pulse-output build connects to PipeWire's pulse server, the most
    # reliable route on a desktop PipeWire box.
    systemd.user.services.squeezelite = {
      description = "Squeezelite (Music Assistant player)";
      wantedBy = [ "default.target" ];
      after = [ "pipewire-pulse.service" ];
      wants = [ "pipewire-pulse.service" ];
      serviceConfig = {
        # -C 5: release the output device 5s after pausing so games/other apps
        # can grab it back; -n: player name; -s: the MA SlimProto server.
        ExecStart = ''${pkgs.squeezelite-pulse}/bin/squeezelite-pulse -s ${cfg.server} -n "${cfg.name}" -C 5'';
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
