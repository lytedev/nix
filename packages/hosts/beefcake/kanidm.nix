{
  config,
  pkgs,
  ...
}:
let
  domain = "idm.h.lyte.dev";
  user = config.systemd.services.kanidm.serviceConfig.User;
  group = config.systemd.services.kanidm.serviceConfig.Group;
  storage-root = "/storage/kanidm";
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
      unitConfig = {
        After = [
          "systemd-tmpfiles-setup.service"
          "systemd-tmpfiles-resetup.service"
        ];
      };

      # get the certificates that caddy provisions for us
      script = ''
        umask 077
        install -d -m 0700 -o "${user}" -g "${group}" "${storage-root}/certs"
        cd /var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/idm.h.lyte.dev
        install -m 0700 -o "${user}" -g "${group}" idm.h.lyte.dev.key idm.h.lyte.dev.crt "${storage-root}/certs"
      '';
      path = with pkgs; [ rsync ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };

    services.kanidm = {
      enableServer = true;
      serverSettings = {
        version = "2";
        inherit domain;
        origin = "https://${domain}";
        bindaddress = "127.0.0.1:8943";
        tls_chain = "${storage-root}/certs/idm.h.lyte.dev.crt";
        tls_key = "${storage-root}/certs/idm.h.lyte.dev.key";
        log_level = "info";
        ldapbindaddress = "127.0.0.1:3636";
        online_backup = {
          path = "${storage-root}/backups/";
          schedule = "00 22 * * *";
          versions = 50;
        };
      };

      unixSettings = {
        # pam_allowed_login_groups = [];
      };

      enableClient = true;
      clientSettings.uri = "https://${domain}";

      migrations.files = {
        "00-groups.hjson" = ./kanidm-migrations/00-groups.hjson;
        "20-oauth2.hjson" = ./kanidm-migrations/20-oauth2.hjson;
        "25-host-accounts.hjson" = ./kanidm-migrations/25-host-accounts.hjson;
        "26-host-beefcake-privileges.hjson" = ./kanidm-migrations/26-host-beefcake-privileges.hjson;
        "30-immich-group.hjson" = ./kanidm-migrations/30-immich-group.hjson;
        "35-immich-mobile-redirects.hjson" = ./kanidm-migrations/35-immich-mobile-redirects.hjson;
      };

      migrations.secretFiles = {
        "10-persons.hjson" = config.sops.secrets.kanidm-persons-migration.path;
        "15-service-accounts.hjson" = config.sops.secrets.kanidm-service-accounts-migration.path;
      };
    };

    sops.secrets.kanidm-persons-migration = {
      sopsFile = ../../../secrets/beefcake/kanidm-migrations.yml;
      key = "persons";
      owner = user;
      group = group;
      mode = "0400";
    };

    sops.secrets.kanidm-service-accounts-migration = {
      sopsFile = ../../../secrets/beefcake/kanidm-migrations.yml;
      key = "service-accounts";
      owner = user;
      group = group;
      mode = "0400";
    };

    services.caddy.virtualHosts.${domain} = {
      extraConfig = ''
        reverse_proxy https://${domain}:8943 {
          transport http {
            tls
            tls_server_name ${domain}
            tls_insecure_skip_verify
          }
        }
      '';
    };

    systemd.services.kanidm = {
      unitConfig = {
        After = [
          "systemd-tmpfiles-setup.service"
          "systemd-tmpfiles-resetup.service"
          "copy-kanidm-certificates-from-caddy.service"
        ];
      };
    };

    networking = {
      extraHosts = ''
        ::1 ${domain}
        127.0.0.1 ${domain}
      '';
    };

    # LDAP bound to localhost only; no firewall rule needed

    # ── OAuth2 secret fetcher ──────────────────────────────────────────
    # Automatically retrieves OAuth2 client secrets from Kanidm after
    # startup and makes them available to consuming services.
    lyte.kanidm-oauth2-secrets = {
      enable = true;
      tokenFile = config.sops.secrets.kanidm-host-beefcake-token.path;
    };

    sops.secrets.kanidm-host-beefcake-token = {
      mode = "0400";
    };
  };
}
