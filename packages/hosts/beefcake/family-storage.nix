{
  # family storage
  users.extraGroups = {
    "family" = { };
  };
  systemd.tmpfiles.settings = {
    "10-family" = {
      "/storage/family" = {
        "d" = {
          mode = "0770";
          user = "root";
          group = "family";
        };
      };
      "/storage/valerie" = {
        "d" = {
          mode = "0700";
          user = "valerie";
          group = "family";
        };
      };
    };
  };
  services.restic.commonPaths = [
    "/storage/family"
    "/storage/valerie"
  ];
}
