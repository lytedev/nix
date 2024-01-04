{...}: {
  users.groups.flanfam = {};

  users.users = {
    flanfam = {
      isNormalUser = true;
      home = "/home/flanfam";
      createHome = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPLXOjupz3ScYjgrF+ehrbp9OvGAWQLI6fplX6w9Ijb daniel@lyte.dev"
      ];
      group = "flanfam";
      extraGroups = ["users" "video"];
      packages = [];
    };
  };
}
