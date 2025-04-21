{
  config,
  pkgs,
  hardware,
  ...
}:
{
  system.stateVersion = "24.05";

  sops = {
    defaultSopsFile = ../../secrets/beefcake/secrets.yml;
    secrets = {
      netlify-ddns-password.mode = "0400";
      nix-cache-priv-key.mode = "0400";
    };
  };

  podman.enable = true;

  services.deno-netlify-ddns-client = {
    enable = true;
    passwordFile = config.sops.secrets.netlify-ddns-password.path;
    username = "beefcake.h";
  };

  environment.systemPackages = with pkgs; [
    aria2
    restic
    btrfs-progs
    zfs
    smartmontools
    htop
    bottom
    curl
    xh
    ghostty-terminfo
  ];

  home-manager.users.daniel = {
    lyte.shell.enable = true;
  };

  /*
    non-root processes and services that access secrets need to be part of
    the 'keys' group?

    citation needed ^ ?

    systemd.services.some-service = {
      serviceConfig.SupplementaryGroups = [ config.users.groups.keys.name ];
    };
    or
    users.users.example-user.extraGroups = [ config.users.groups.keys.name ];

    TODO: declarative directory quotas? for storage/$USER and /home/$USER
  */

  imports =
    [
      hardware.common-cpu-intel
    ]
    ++ (builtins.map import [
      ./beefcake/hardware.nix
      ./beefcake/networking.nix

      ./beefcake/nix-serve.nix
      ./beefcake/headscale.nix
      ./beefcake/soju.nix
      ./beefcake/nextcloud.nix
      ./beefcake/plausible.nix
      ./beefcake/clickhouse.nix
      ./beefcake/family-storage.nix
      ./beefcake/daniel.nix
      ./beefcake/jellyfin.nix
      ./beefcake/daniel.nix
      ./beefcake/postgres.nix
      ./beefcake/other-users.nix
      ./beefcake/restic.nix
      ./beefcake/caddy.nix
      ./beefcake/forgejo.nix
      ./beefcake/vaultwarden.nix
      ./beefcake/atuin.nix
      ./beefcake/kanidm.nix
      ./beefcake/minecraft-server-containers.nix
      ./beefcake/audiobookshelf.nix
      ./beefcake/prometheus.nix
      ./beefcake/grafana.nix
      ./beefcake/paperless.nix
      ./beefcake/actual.nix
      ./beefcake/factorio-servers.nix
      ./beefcake/conduwuit.nix
      ./beefcake/element-web.nix
      ./beefcake/arr.nix
    ]);

  /*
    if fans are loud:

    # enable manual fan control
    sudo nix run nixpkgs#ipmitool -- raw 0x30 0x30 0x01 0x00

    # set fan speed to last byte as decimal
    sudo nix run nixpkgs#ipmitool -- raw 0x30 0x30 0x02 0xff 0x00
  */
}
