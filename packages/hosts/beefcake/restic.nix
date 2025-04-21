{ pkgs, config, ... }:
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
    createHome = true;
    home = "/storage/backups/restic";
    group = "restic";
    extraGroups = [ "sftponly" ];
    openssh.authorizedKeys.keys = [ ] ++ config.users.users.daniel.openssh.authorizedKeys.keys;
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
          ''sftp.command="ssh beefcake@rascal.hare-cod.ts.net -i ${config.sops.secrets.restic-rascal-ssh-private-key.path} -s sftp"''
        ];
        repository = "sftp://beefcake@rascal.hare-cod.ts.net://storage/backups/beefcake";
      };
      # TODO: add ruby?
      benland = defaults // {
        extraOptions = [
          ''sftp.command="ssh daniel@n.benhaney.com -p 10022 -i ${config.sops.secrets.restic-ssh-priv-key-benland.path} -s sftp"''
        ];
        repository = "sftp://daniel@n.benhaney.com://storage/backups/beefcake";
      };
    };

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
      set -p pipefail
      echo "Previous (last run's current): $(cat current)"
      rm -f previous
      echo "Moving current to previous..."
      mv current previous || true
      date +%s > current
      echo "New: $(cat current)"
    '';
    # TODO: depends on systemd.tmpfiles?
    path = with pkgs; [ restic ];
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
        --option sftp.command="ssh beefcake@rascal.hare-cod.ts.net -i '${config.sops.secrets.restic-rascal-ssh-private-key.path}' -s sftp" \
        --repo='sftp://beefcake@rascal.hare-cod.ts.net://storage/backups/beefcake' \
        --password-file='${config.sops.secrets.restic-rascal-passphrase.path}' \
        restore latest --include /storage/backups/canary --target ./rascal/
      echo "Restored from rascal"

      # check benland
      # TODO: benland should have its own passwordfile, should be able to update the repository?
      restic \
        --option sftp.command="ssh beefcake@rascal.hare-cod.ts.net -i '${config.sops.secrets.restic-rascal-ssh-private-key.path}' -s sftp" \
        --repo='sftp://beefcake@rascal.hare-cod.ts.net://storage/backups/beefcake' \
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
