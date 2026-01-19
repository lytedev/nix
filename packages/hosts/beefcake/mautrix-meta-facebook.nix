{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.restic.commonPaths = [ "/var/lib/mautrix-meta-facebook" ];

  services.mautrix-meta.instances.facebook = {
    enable = true;
    settings = {
      homeserver = {
        address = "http://localhost:6167";
        domain = "lyte.dev";
      };
      appservice = {
        address = "http://localhost:29319";
        hostname = "127.0.0.1";
        port = 29319;
      };
      network.mode = "facebook";
      bridge = {
        permissions = {
          "@daniel:lyte.dev" = "admin";
        };
      };
      encryption = {
        allow = true;
        default = true;
        pickle_key = "mautrix.bridge.e2ee";
      };
    };
  };
}
