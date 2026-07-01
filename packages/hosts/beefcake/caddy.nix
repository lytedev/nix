{
  config,
  pkgs,
  ...
}:
{
  # TSIG secret for the wildcard *.k.lyte.dev DNS-01 ACME challenge.
  # Reuses the existing beefcake-h key (ACL-update on the lyte.dev zone).
  # Server/key name pulled from lyte.dns-updater so they stay in sync with
  # the dynamic DNS client configured on this host.
  sops.templates."caddy-tsig.env" = {
    owner = "caddy";
    group = "caddy";
    content = ''
      TSIG_KEY_NAME=${config.lyte.dns-updater.tsigKeyName}
      TSIG_KEY_ALG=${config.lyte.dns-updater.tsigAlgorithm}
      TSIG_SERVER=${config.lyte.dns-updater.server}:53
      TSIG_KEY=${config.sops.placeholder.tsig-beefcake-h}
    '';
  };

  # systemd sandboxing for the sole :443 edge daemon. The upstream NixOS caddy
  # module already sets NoNewPrivileges / ProtectHome / PrivateDevices /
  # StateDirectory=caddy / LogsDirectory=caddy; this overlay adds the rest so a
  # code-exec bug in caddy (or a Go plugin) can't reach the host. Keys the module
  # already defines are intentionally NOT repeated here to avoid eval conflicts.
  #
  # Deliberately omitted, with reasons:
  #   - MemoryDenyWriteExecute: caddy is pure Go (no JIT) so it *should* tolerate
  #     W^X, but this is unverified on this host; left off to avoid a startup
  #     regression. Safe to add + test later for the last 0.1.
  #   - PrivateNetwork / IPAddressDeny: caddy needs arbitrary outbound (ACME,
  #     rfc2136 DNS-01, reverse_proxy upstreams) so an address allow-list isn't
  #     practical here.
  #   - PrivateUsers: would namespace CAP_NET_BIND_SERVICE and break binding
  #     80/443 on the host.
  # Note: dropping CAP_NET_ADMIN means caddy can't bump the UDP receive-buffer
  # size for HTTP/3, so it logs a benign "failed to sufficiently increase receive
  # buffer size" warning on start. HTTP/3 still works. See
  # https://github.com/quic-go/quic-go/wiki/UDP-Buffer-Sizes
  systemd.services.caddy.serviceConfig = {
    EnvironmentFile = [
      config.sops.templates."caddy-tsig.env".path
    ];

    # caddy only needs to bind low ports; drop everything else (incl. NET_ADMIN).
    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];

    # StateDirectory=caddy (/var/lib/caddy) and LogsDirectory=caddy
    # (/var/log/caddy) remain writable automatically; everything else read-only.
    # /storage/files.lyte.dev is served read-only (file_server browse), so it
    # does not need a ReadWritePaths entry.
    ProtectSystem = "strict";
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    ProtectHostname = true;
    ProtectProc = "invisible";
    ProcSubset = "pid";
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    RemoveIPC = true;
    UMask = "0077";
    SystemCallArchitectures = "native";
    SystemCallFilter = [ "@system-service" ];
    SystemCallErrorNumber = "EPERM";
  };

  systemd.tmpfiles.settings = {
    "10-caddy" = {
      "/storage/files.lyte.dev" = {
        "d" = {
          mode = "2775";
          user = "root";
          group = "wheel";
        };
      };
    };
  };
  services.restic.commonPaths = [
    "/storage/files.lyte.dev"
  ];
  services.caddy = {
    # TODO: 502 and other error pages
    enable = true;
    email = "daniel@lyte.dev";
    adapter = "caddyfile";

    # rfc2136 plugin for DNS-01 wildcard cert on *.k.lyte.dev. To bump
    # the plugin version, set `hash = lib.fakeHash`, build once, paste
    # the reported hash back here.
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/rfc2136@v1.0.0" ];
      hash = "sha256-Vfy1hrnzENtYpJpXk5+GW8G5Gvw4Mo2WWyBYgb54Ap8=";
    };

    virtualHosts = {
      "http://files.beefcake.hare-cod.ts.net" = {
        extraConfig = ''
          header {
            Access-Control-Allow-Origin "{http.request.header.Origin}"
            Access-Control-Allow-Credentials true
            Access-Control-Allow-Methods *
            Access-Control-Allow-Headers *
            Vary Origin
            defer
          }

          file_server browse {
            ## browse template
            ## hide .*
            root /storage/files.lyte.dev
          }
        '';
      };
      "http://files.beefcake.lan" = {
        extraConfig = ''
          header {
            Access-Control-Allow-Origin "{http.request.header.Origin}"
            Access-Control-Allow-Credentials true
            Access-Control-Allow-Methods *
            Access-Control-Allow-Headers *
            Vary Origin
            defer
          }

          file_server browse {
            ## browse template
            ## hide .*
            root /storage/files.lyte.dev
          }
        '';
      };
      "files.lyte.dev" = {
        # TODO: customize the files.lyte.dev template?
        extraConfig = ''
          header {
            Access-Control-Allow-Origin "{http.request.header.Origin}"
            Access-Control-Allow-Credentials true
            Access-Control-Allow-Methods *
            Access-Control-Allow-Headers *
            Vary Origin
            defer
          }

          file_server browse {
            ## browse template
            ## hide .*
            root /storage/files.lyte.dev
          }
        '';
      };
      "hookshot.matrix.lyte.dev".extraConfig = ''
        reverse_proxy :9500
      '';

      # Catch-all for cluster-managed apps. caddy stays the sole edge: it
      # terminates TLS for every *.k.lyte.dev host (one wildcard cert via DNS-01)
      # and forwards plain HTTP to traefik's loopback NodePort. traefik (the
      # in-cluster ingress) routes by Host to the right app's Service, so a new
      # app needs only an Ingress resource — no DNS, cert, or caddy change.
      "*.k.lyte.dev".extraConfig = ''
        tls {
          dns rfc2136 {
            key_name {env.TSIG_KEY_NAME}
            key_alg {env.TSIG_KEY_ALG}
            key {env.TSIG_KEY}
            server {env.TSIG_SERVER}
          }
        }
        reverse_proxy http://127.0.0.1:30081 {
          header_up Host {host}
        }
      '';
    };
    # acmeCA = "https://acme-staging-v02.api.letsencrypt.org/directory";
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
