{ config, ... }:
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
}
