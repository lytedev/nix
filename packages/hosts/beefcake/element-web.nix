{ pkgs, ... }:
{
  services.caddy.virtualHosts."chat.lyte.dev".extraConfig = ''
    root * ${pkgs.element-web}
    file_server

    handle /config.json {
      root * ${./element-web}
      file_server
    }
  '';
}
