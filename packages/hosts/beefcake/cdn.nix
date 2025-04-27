{ ... }:
{
  # is it still a CDN if the N is one host...?
  services.caddy = {
    virtualHosts = {
      "tasks.h.lyte.dev" = {
        extraConfig = ''
          root * /srv/h.lyte.dev
          encode
          try_files {path} /index.html
          file_server {
            hide .*
          }
        '';
      };
      "http://beefcake.hare-cod.ts.net" = {
        extraConfig = ''
          root * /srv/h.lyte.dev
          encode
          try_files {path} /index.html
          file_server {
            hide .*
          }
        '';
      };
      "http://beefcake.lan" = {
        extraConfig = ''
          root * /srv/h.lyte.dev
          encode
          try_files {path} /index.html
          file_server {
            hide .*
          }
        '';
      };
    };
  };
}
