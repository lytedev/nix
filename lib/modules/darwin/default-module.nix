{
  self,
  sops-nix,
  ...
}:
{
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = with self.outputs.darwinModules; [
    sops-nix.darwinModules.sops
    shell-defaults-and-applications
    user-env
  ];

  config = {
    system.configurationRevision = toString (
      self.shortRev or self.dirtyShortRev or self.lastModified or "unknown"
    );

    lyte.flakeStorePath = "${self}";
    lyte.shell.enable = lib.mkDefault true;

    nixpkgs = {
      config.allowUnfree = lib.mkDefault true;
      overlays = [ self.flakeLib.forSelfOverlay ];
    };

    nix = lib.mkIf config.nix.enable {
      settings = {
        trusted-users = [
          "@admin"
          config.lyte.username
        ];
        accept-flake-config = true;
      }
      // ((import ../../../flake.nix).nixConfig);
    };

    sops = {
      age = {
        sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];
        keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
        generateKey = lib.mkDefault true;
      };
    };

    users.knownUsers = [ config.lyte.username ];
    users.users.${config.lyte.username} = {
      home = lib.mkDefault "/Users/${config.lyte.username}";
      shell = lib.mkIf config.lyte.shell.enable pkgs.fish;
    };

    security.pam.services.sudo_local.touchIdAuth = true;
  };
}
