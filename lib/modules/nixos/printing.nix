{
  pkgs,
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.services.printing.enable {
    services.printing.browsing = true;
    services.printing.browsedConf = ''
      BrowseDNSSDSubTypes _cups,_print
      BrowseLocalProtocols all
      BrowseRemoteProtocols all
      CreateIPPPrinterQueues All

      BrowseProtocols all
    '';
    services.printing.drivers = [ pkgs.gutenprint ];
  };
}
