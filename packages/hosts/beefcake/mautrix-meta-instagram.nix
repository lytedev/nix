{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.restic.commonPaths = [ "/var/lib/mautrix-meta-instagram" ];

  services.mautrix-meta.instances.instagram = {
    enable = true;
    settings = {
      homeserver = {
        address = "http://localhost:6167";
        domain = "lyte.dev";
      };
      appservice = {
        address = "http://localhost:29320";
        hostname = "127.0.0.1";
        port = 29320;
      };
      network.mode = "instagram";
      bridge = {
        permissions = {
          "@daniel:lyte.dev" = "admin";
        };
      };
      encryption = {
        allow = true;
        default = true;
      };
    };
  };
}
