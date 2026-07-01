{
  pkgs,
  config,
  lib,
  ...
}:
let
  # Reuse the already-provisioned disk-alert webhook (declared in disk-alerts.nix)
  # so restic failures land in the same infra-health Matrix room without minting a
  # second webhook/secret. Split into a dedicated secret later if the volume warrants.
  webhookSecret = config.sops.secrets.disk-alert-webhook-url.path;

  # Fired via OnFailure=restic-backup-notify@<failing-unit>.service. The instance
  # name (%i) is the unit that failed; we POST a one-liner to the hookshot webhook.
  # Best-effort: it must never fail (a missing webhook is not an alerting emergency).
  resticBackupNotify = pkgs.writeShellApplication {
    name = "restic-backup-notify";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      jq
    ];
    text = ''
      webhook="$(cat ${webhookSecret} 2>/dev/null || true)"
      if [ -z "$webhook" ]; then
        echo "restic-backup-notify: no webhook url available" >&2
        exit 0
      fi
      unit="''${1:-unknown restic unit}"
      host="$(uname -n)"
      text="$(printf '🔴 restic failure on %s: %s\n\nInvestigate: journalctl -u %s -n 80' "$host" "$unit" "$unit")"
      payload="$(jq -n --arg t "$text" '{text: $t}')"
      curl --fail --silent --show-error --max-time 20 \
        --header 'Content-Type: application/json' \
        --data "$payload" \
        "$webhook" >/dev/null || echo "restic-backup-notify: post failed" >&2
    '';
  };
in
{
  # restic backups
  sops.secrets = {
    restic-ssh-priv-key-benland = {
      mode = "0400";
    };
    restic-rascal-passphrase = {
      mode = "0400";
    };
    restic-rascal-ssh-private-key = {
      mode = "0400";
    };
  };
  users.groups.restic = { };
  users.users.restic = {
    # used for other machines to backup to
    isSystemUser = true;
    home = "/storage/backups/restic";
    group = "restic";
    extraGroups = [ "sftponly" ];
    openssh.authorizedKeys.keys = config.lyte.userSshKeys;
  };
  services.openssh.extraConfig = ''
    Match Group sftponly
      ChrootDirectory /storage/backups/%u
      ForceCommand internal-sftp
      AllowTcpForwarding no
  '';
  systemd.tmpfiles.settings = {
    "10-backups-local" = {
      "/storage/backups/local" = {
        "d" = {
          mode = "0750";
          user = "root";
          group = "wheel";
        };
      };
    };
    # ChrootDirectory requires root-owned dir; writable repo/ subdir for actual data
    "10-backups-restic" = {
      "/storage/backups/restic" = {
        "d" = {
          mode = "0755";
          user = "root";
          group = "root";
        };
      };
      "/storage/backups/restic/repo" = {
        "d" = {
          mode = "0750";
          user = "restic";
          group = "restic";
        };
      };
    };
  };
  services.restic.backups =
    let
      # TODO: How do I set things up so that a compromised server doesn't have access to my backups so that it can corrupt or ransomware them?
      defaults = {
        passwordFile = config.sops.secrets.restic-rascal-passphrase.path;
        paths = config.services.restic.commonPaths ++ [
        ];
        initialize = true;
        exclude = [ ];
        # Retention: without a forget policy every 2×/day snapshot is kept
        # forever and the repos grow unbounded. The module runs
        # `restic unlock` + `restic forget --prune` AFTER each backup.
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
        ];
        timerConfig = {
          OnCalendar = [
            "04:45"
            "17:45"
          ];
        };
      };
    in
    {
      local = defaults // {
        repository = "/storage/backups/local";
      };
      rascal = defaults // {
        extraOptions = [
          ''sftp.command="ssh beefcake@rascal.internal.vpn.h.lyte.dev -i ${config.sops.secrets.restic-rascal-ssh-private-key.path} -s sftp"''
        ];
        repository = "sftp://beefcake@rascal.internal.vpn.h.lyte.dev://repo";
      };
      # TODO: add ruby?
      benland = defaults // {
        extraOptions = [
          ''sftp.command="ssh daniel@n.benhaney.com -p 10022 -i ${config.sops.secrets.restic-ssh-priv-key-benland.path} -s sftp"''
        ];
        repository = "sftp://daniel@n.benhaney.com://storage/backups/beefcake";
      };
    };

  # Templated Matrix notifier fired by OnFailure on the backup + canary units.
  # Previously a broken backup or a failing restore-canary was entirely silent.
  systemd.services."restic-backup-notify@" = {
    description = "Notify Matrix on restic failure of %i";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe resticBackupNotify} %i";
    };
  };

  # Wire OnFailure onto the module-generated backup units (merged into their
  # existing definitions). %n is the failing unit's full name, passed as the
  # notifier's instance (%i).
  systemd.services.restic-backups-local.unitConfig.OnFailure = [ "restic-backup-notify@%n.service" ];
  systemd.services.restic-backups-rascal.unitConfig.OnFailure = [ "restic-backup-notify@%n.service" ];
  systemd.services.restic-backups-benland.unitConfig.OnFailure = [
    "restic-backup-notify@%n.service"
  ];

  systemd.tmpfiles.settings."10"."/storage/backups/canary".d = {
    mode = "0750";
    user = "root";
    group = "wheel";
  };
  services.restic.commonPaths = [ "/storage/backups/canary" ];

  # TODO: schedule this for right before backups instead of intervals based on boot time
  systemd.timers."backup-canary-write" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30m"; # 30 minutes after booting
      OnUnitActiveSec = "1d"; # every day afterwards
      Unit = "backup-canary-write.service";
    };
  };

  systemd.services."backup-canary-write" = {
    script = ''
      set -xeu
      set -o pipefail
      echo "Previous (last run's current): $(cat current)"
      rm -f previous
      echo "Moving current to previous..."
      mv current previous || true
      date +%s > current
      echo "New: $(cat current)"
    '';
    # TODO: depends on systemd.tmpfiles?
    path = with pkgs; [ restic ];
    unitConfig.OnFailure = [ "restic-backup-notify@%n.service" ];
    serviceConfig = {
      WorkingDirectory = "/storage/backups/canary";
      Type = "oneshot";
    };
  };

  # TODO: schedule this properly for after backups have run
  systemd.timers."backup-canary-read" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30m"; # 30 minutes after booting
      OnUnitActiveSec = "1d"; # every day afterwards
      Unit = "backup-canary-read.service";
    };
  };

  systemd.services."backup-canary-read" = {
    # TODO: private dir for this service?
    path = with pkgs; [
      restic
      openssh
      diffutils
    ];
    unitConfig.OnFailure = [ "restic-backup-notify@%n.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -eux
      set -o pipefail
      umask 027
      d="$(mktemp -d)"
      echo "Working in $d"
      trap "rm -fr '$d'" SIGINT SIGTERM EXIT
      pushd "$d" || exit 1
      mkdir -p ./rascal ./benland ./local
      # check rascal
      restic \
        --option sftp.command="ssh beefcake@rascal.internal.vpn.h.lyte.dev -i '${config.sops.secrets.restic-rascal-ssh-private-key.path}' -s sftp" \
        --repo='sftp://beefcake@rascal.internal.vpn.h.lyte.dev://repo' \
        --password-file='${config.sops.secrets.restic-rascal-passphrase.path}' \
        restore latest --include /storage/backups/canary --target ./rascal/
      echo "Restored from rascal"

      # check benland
      # TODO: benland should have its own passwordfile, should be able to update the repository?
      restic \
        --option sftp.command="ssh daniel@n.benhaney.com -p 10022 -i '${config.sops.secrets.restic-ssh-priv-key-benland.path}' -s sftp" \
        --repo='sftp://daniel@n.benhaney.com://storage/backups/beefcake' \
        --password-file='${config.sops.secrets.restic-rascal-passphrase.path}' \
        restore latest --include /storage/backups/canary --target ./benland/
      echo "Restored from benland"

      # check local
      restic \
        --repo='/storage/backups/local' \
        --password-file='${config.sops.secrets.restic-rascal-passphrase.path}' \
        restore latest --include /storage/backups/canary --target ./local/
      echo "Restored from local"

      cat ./{rascal,benland,local}/storage/backups/canary/current

      if ! diff ./rascal/storage/backups/canary/current ./benland/storage/backups/canary/current || ! diff ./rascal/storage/backups/canary/current ./local/storage/backups/canary/current; then
        echo "At least one canary file differs from the others, indicating backups are out of sync in at least one location! Investigate immediately!"
        exit 1
      fi

      # TODO: the date in the file should not be more than 48 hours old
      let "max = 60 * 60 * 24 * 2"
      let "elapsed = $(date +%s) - $(cat ./rascal/storage/backups/canary/current)"

      if [[ $elapsed -gt $max ]]; then
        echo "All canary files indicate backups are more than 48 hours old! Investigate immediately!"
        exit 1
      fi

      exit 0

      # TODO: should do an actual disaster recovery drill to ensure I can recover from losing all personal devices
      # My guess is that the primary password vault's secret key needs to be recoverable somehow
      # From there, the password vault can be retrieved from the cloud location and used to retrieve the restic keys
      # Once the restic keys and google login are retrieved, tailscale login and ACLs should enable connectivity and auth and the keys can be used to download backups and decrypt
    '';
  };
}
