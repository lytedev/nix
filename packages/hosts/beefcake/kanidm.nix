{
  config,
  pkgs,
  ...
}:
let
  domain = "idm.h.lyte.dev";
  name = "kanidm";
  user = name;
  group = name;
  storage = "/storage/${name}";
in
{
  # kanidm
  config = {
    # reload certs from caddy every 5 minutes
    # TODO: ideally some kind of file watcher service would make way more sense here?
    # or we could simply setup the permissions properly somehow?
    systemd.timers."copy-kanidm-certificates-from-caddy" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "10m"; # 10 minutes after booting
        OnUnitActiveSec = "5m"; # every 5 minutes afterwards
        Unit = "copy-kanidm-certificates-from-caddy.service";
      };
    };

    systemd.services."copy-kanidm-certificates-from-caddy" = {
      # get the certificates that caddy provisions for us
      script = ''
        umask 077
        # this line should be unnecessary now that we have this in tmpfiles
        install -d -m 0700 -o "${name}" -g "${name}" "${storage}/data" "${storage}/certs"
        cd /var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/idm.h.lyte.dev
        install -m 0700 -o "${name}" -g "${name}" idm.h.lyte.dev.key idm.h.lyte.dev.crt "${storage}/certs"
      '';
      path = with pkgs; [ rsync ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };

    systemd.tmpfiles.settings."10-kanidm" = {
      "${config.services.kanidm.serverSettings.online_backup.path}".d = {
        user = name;
        group = name;
        mode = "0700";
      };
      "${storage}/data".d = {
        inherit user group;
        mode = "0700";
      };
      "${storage}/certs".d = {
        inherit user group;
        mode = "0700";
      };
    };

    services.kanidm = {
      enableServer = true;
      serverSettings = {
        inherit domain;
        origin = "https://${domain}";
        bindaddress = "127.0.0.1:8443";
        tls_chain = "${storage}/certs/idm.h.lyte.dev.crt";
        tls_key = "${storage}/certs/idm.h.lyte.dev.key";
        log_level = "info";
        # ldapbindaddress = "127.0.0.1:3636";
        online_backup = {
          path = "${storage}/backups/";
          schedule = "00 22 * * *";
          versions = 50;
        };
      };

      unixSettings = {
        # pam_allowed_login_groups = [];
      };

      enableClient = true;
      clientSettings = {
        uri = "https://idm.h.lyte.dev";
      };

      provision = {
        # enable = true;
        # instanceUrl = "https://${domain}";
        # adminPasswordFile = config.sops.secrets.kanidm-admin-password-file.path
        # idmAdminPasswordFile = config.sops.secrets.kanidm-admin-password-file.path
        # autoRemove = true;
        # groups = {
        #   myGroup = {
        #     members = ["myUser" /* ...*/];
        #   }
        # };
        # persons = {
        #   myUser = {
        #     displayName = "display name";
        #     legalName = "My User";
        #     mailAddresses = ["myuser@example.com"];
        #     groups = ["myGroup"];
        #   }
        # };
        # systems = {
        #   oauth2 = {
        #     mySystem = {
        #       enableLegacyCrypto = false;
        #       enableLocalhostRedirects = true; # only for public
        #       allowInsecureClientDisablePkce = false;
        #       basicSecretFile = config.sops.secrets.basic-secret-file...
        #       claimMap = {};
        #     };
        #   };
        # };
      };
    };

    services.caddy.virtualHosts."idm.h.lyte.dev" = {
      extraConfig = ''reverse_proxy https://idm.h.lyte.dev:8443'';
    };

    networking = {
      extraHosts = ''
        ::1 idm.h.lyte.dev
        127.0.0.1 idm.h.lyte.dev
      '';
    };
  };
}
