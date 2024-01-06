{...}: {
  users.groups.flanfamkiosk = {};

  users.users = {
    flanfamkiosk = {
      isNormalUser = true;
      home = "/home/flanfamkiosk";
      createHome = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev"
      ];
      group = "flanfamkiosk";
      extraGroups = ["users" "video"];
      packages = [];
    };
  };
}
