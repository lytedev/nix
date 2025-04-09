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
        inherit domain;
        origin = "https://${domain}";
        bindaddress = "127.0.0.1:8443";
        tls_chain = "${storage-root}/certs/idm.h.lyte.dev.crt";
        tls_key = "${storage-root}/certs/idm.h.lyte.dev.key";
        log_level = "info";
        ldapbindaddress = "0.0.0.0:3636";
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

      provision = {
        enable = false;
        instanceUrl = "https://${domain}";
        # adminPasswordFile = config.sops.secrets.kanidm-admin-password-file.path
        # idmAdminPasswordFile = config.sops.secrets.kanidm-admin-password-file.path
        autoRemove = true;
        groups = {
          administrators = {
            members = [ "daniel" ];
          };
          family = {
            members = [
              "valerie"
              "daniel"
            ];
          };
          broad-family = {
            members = [
              # ...
            ];
          };
          trusted-friends = {
            members = [
              # ...
            ];
          };
          non-technical-friends = {
            members = [
              # ...
            ];
          };
        };
        persons = {
          daniel = {
            displayName = "Daniel Flanagan";
            legalName = "Daniel Flanagan";
            mailAddresses = [ "daniel@lyte.dev" ];
            groups = [
              "administrators"
              "family"
            ];
          };
          valerie = {
            displayName = "Valerie";
            mailAddresses = [ ];
            groups = [
              "family"
            ];
          };
        };
        systems = {
          oauth2 = {
            test1 = {
              displayName = "Test One";
              originUrl = "http://localhost:5173/";
              originLanding = "http://localhost:5173/idm/origin-landing";
              enableLegacyCrypto = false;
              enableLocalhostRedirects = true; # only for public
              # public = true;
              allowInsecureClientDisablePkce = false;
              # basicSecretFile =
              # claimMap = { };
            };
          };
        };
      };
    };

    services.caddy.virtualHosts.${domain} = {
      extraConfig = ''reverse_proxy https://${domain}:8443'';
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

    networking.firewall.allowedTCPPorts = [ 3636 ];
  };
}
