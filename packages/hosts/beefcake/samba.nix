{ pkgs, ... }:
{
  users.groups.valerie.members = [ "valerie" ];
  users.users.valerie = {
    isNormalUser = true;
    home = "/home/valerie";
    description = "Valerie";
    createHome = true;
    group = "valerie";
    extraGroups = [
      "users"
      "video"
      "jellyfin"
      "audiobookshelf"
      "family"
    ];
  };

  systemd.tmpfiles.settings."10" = {
    "/storage/public".d = {
      mode = "0777";
      user = "nobody";
      group = "nogroup";
    };
    "/storage/family".d = {
      mode = "0770";
      user = "nobody";
      group = "family";
    };
    "/storage/valerie".d = {
      mode = "0700";
      user = "valerie";
      group = "family";
    };
    "/storage/daniel".d = {
      mode = "0700";
      user = "daniel";
      group = "nogroup";
    };
    "/storage/daniel/critical".d = {
      mode = "0700";
      user = "daniel";
      group = "nogroup";
    };
  };

  users.extraGroups = {
    "family" = { };
  };

  services.restic.commonPaths = [
    "/storage/family"
    "/storage/valerie"
    "/storage/daniel"
  ];

  services = {
    samba = {
      package = pkgs.samba4Full;
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          # "server smb encrypt" = "required";
          # ^^ Note: Breaks `smbclient -L <ip/host> -U%` by default, might require the client to set `client min protocol`?
          # "server min protocol" = "SMB3_00";
          "guest account" = "nobody";
        };
        public = {
          path = "/storage/public";
          writable = "true";
          comment = "Hello World!";
          "guest ok" = "yes";
          "available" = "yes";
          "browsable" = "yes";
        };
        fam = {
          path = "/storage/family";
          writable = "true";
          "guest ok" = "no";
          "available" = "yes";
          "browsable" = "yes";
        };
        valerie = {
          path = "/storage/valerie";
          writable = "true";
          "guest ok" = "no";
          "available" = "yes";
          "browsable" = "yes";
        };
        daniel = {
          path = "/storage/daniel";
          writable = "true";
          "guest ok" = "no";
          "available" = "yes";
          "browsable" = "yes";
        };
      };
    };
    avahi = {
      publish.enable = true;
      publish.userServices = true;
      # nssmdns4 = true; # probably not needed
      enable = true;
      openFirewall = true;
    };
    samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
  };
}
