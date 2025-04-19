{
  config,
  lib,
  ...
}:
let
  cfg = config.services.livebook;
in
{
  config = lib.mkIf cfg.enableUserService {
    sops.secrets.livebook.mode = "0400";
    services.livebook = {
      environmentFile = config.sops.secrets.livebook.path;
    };
  };
}
