{
  services.restic.commonPaths = [
    "/var/lib/soju"
    "/var/lib/private/soju"
  ];
  services.soju = {
    enable = true;
    listen = [ "irc+insecure://:6667" ]; # tailscale only
  };
}
