{
  config,
  pkgs,
  lib,
  ...
}:
let
  dataDir = "/storage/matrix-hookshot";
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

  services.matrix-hookshot = {
    enable = true;
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
    };
  };
}
