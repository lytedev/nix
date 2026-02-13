{
  config,
  pkgs,
  lib,
  ...
}:
let
  dataDir = "/storage/matrix-hookshot";
  registrationFile = "${dataDir}/registration.yaml";
  port = 9993;
  webhookPort = 9500;
in
{
  services.restic.commonPaths = [ dataDir ];

  systemd.tmpfiles.settings."10-matrix-hookshot".${dataDir}.d = {
    user = "matrix-hookshot";
    group = "matrix-hookshot";
    mode = "0700";
  };

  users.users.matrix-hookshot = {
    isSystemUser = true;
    group = "matrix-hookshot";
    home = dataDir;
    description = "Matrix Hookshot bridge user";
  };

  users.groups.matrix-hookshot = { };

  services.matrix-hookshot = {
    enable = true;
    inherit registrationFile;
    serviceDependencies = [ "tuwunel.service" ];
    settings = {
      bridge = {
        domain = "lyte.dev";
        url = "http://localhost:6167";
        mediaUrl = "https://matrix.lyte.dev";
        port = port;
        bindAddress = "127.0.0.1";
      };
      listeners = [
        {
          port = webhookPort;
          bindAddress = "0.0.0.0";
          resources = [ "webhooks" ];
        }
      ];
      generic = {
        enabled = true;
        urlPrefix = "https://hookshot.matrix.lyte.dev/webhook";
        allowJsTransformationFunctions = true;
        userIdPrefix = "hookshot_";
      };
      permissions = [
        {
          actor = "@daniel:lyte.dev";
          services = [
            {
              service = "*";
              level = "admin";
            }
          ];
        }
      ];
      logging = {
        level = "info";
      };
      passFile = "${dataDir}/passkey.pem";
    };
  };

  # Generate registration file on first run if it doesn't exist
  systemd.services.matrix-hookshot.preStart = lib.mkAfter ''
        if [ ! -f '${registrationFile}' ]; then
          AS_TOKEN="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
          HS_TOKEN="$(${pkgs.openssl}/bin/openssl rand -hex 32)"

          cat > '${registrationFile}' <<YAML
    id: matrix-hookshot
    as_token: $AS_TOKEN
    hs_token: $HS_TOKEN
    namespaces:
      users:
        - regex: "@hookshot_.*:lyte\\.dev"
          exclusive: true
      rooms: []
      aliases: []
    sender_localpart: hookshot
    url: "http://localhost:${toString port}"
    rate_limited: false
    YAML

          chmod 640 '${registrationFile}'
          echo ""
          echo "============================================="
          echo "HOOKSHOT REGISTRATION FILE GENERATED"
          echo "============================================="
          echo "You must register this appservice with Tuwunel."
          echo "In the #admins Matrix room, run:"
          echo "  !admin appservices register"
          echo "Then paste the contents of:"
          echo "  ${registrationFile}"
          echo "============================================="
          echo ""
        fi
  '';
}
