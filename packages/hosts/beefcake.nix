{
  config,
  pkgs,
  hardware,
  ...
}:
{
  system.stateVersion = "24.05";

  # Required for mautrix bridges with E2EE support (libolm is deprecated but still needed)
  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
    "unifi-controller-9.5.21"
  ];

  sops = {
    defaultSopsFile = ../../secrets/beefcake/secrets.yml;
    secrets = {
      netlify-ddns-password.mode = "0400";
      nix-cache-priv-key.mode = "0400";
      # knot (running as the `knot` user) reads this key in its preStart, as
      # beefcake is the lyte.dev DNS primary, so it must be group-readable
      # by knot — matching the other tsig keys + pebble's convention. root (and
      # the dns-updater, which runs as root) still read it fine.
      tsig-beefcake-h = {
        mode = "0440";
        group = "knot";
      };
    };
  };

  lyte.server.enable = true;
  lyte.podman.enable = true;
  lyte.headscale.usePreAuthKey = true;

  # Keep existing DDNS client during parallel-run phase
  services.deno-netlify-ddns-client = {
    enable = true;
    passwordFile = config.sops.secrets.netlify-ddns-password.path;
    username = "beefcake.h";
  };

  # --- Knot DNS dynamic updater (replaces deno-netlify-ddns long-term) ---
  lyte.dns-updater = {
    enable = true;
    # beefcake is the active hidden primary (see ./beefcake/dns-primary.nix), so
    # the updater writes dynamic records to the LOCAL knot; beefcake signs + serves
    # them, and pebble (secondary) + the 1984 nameservers pull them via AXFR. This
    # is the permanent topology, not a temporary retarget.
    server = "127.0.0.1";
    zone = "lyte.dev";
    tsigKeyFile = config.sops.secrets.tsig-beefcake-h.path;
    tsigKeyName = "beefcake-h";
    records = [
      "beefcake.h"
      "paperless.h"
      "git"
      "grafana.h"
      "prometheus.h"
      "finances.h"
      "video"
      "video.h"
      "audio"
      "audio.h"
      "tasks.h"
      "spacetimedb.h"
      "idm.h"
      "*.vpn.h"
      "vpn4.h"
      "vpn.h"
      "nix.h"
      "nextcloud.h"
      "onlyoffice.h"
      "atuin.h"
      "mail"
      "files"
      "a"
      "api"
      "matrix"
      "hookshot.matrix"
      "element"
      "chat"
      "bw"
      "webmail"
      "photos"
      "hearth.h"
      "openobserve.h"
      "syncthing.h"
    ];
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

  lyte.shell.enable = true;

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

  imports = [
    hardware.common-cpu-intel
  ]
  ++ (builtins.map import [
    ./beefcake/hardware.nix
    ./beefcake/networking.nix

    ./beefcake/nix-serve.nix
    ./beefcake/headscale.nix
    # ./beefcake/soju.nix  # replaced by heisenbridge for IRC-via-Matrix
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
    ./beefcake/jonland.nix
    ./beefcake/prom2.nix
    ./beefcake/audiobookshelf.nix
    ./beefcake/opentelemetry-collector.nix
    # ./beefcake/grafana.nix  # Disabled - replaced by OpenObserve
    ./beefcake/openobserve.nix
    ./beefcake/paperless.nix
    ./beefcake/mosquitto.nix
    # Disabled until real secrets are set (placeholder channel URL / Matrix
    # creds would fail-loop). Re-enable once meshtastic-channel-url +
    # mmrelay-credentials are filled in sops.
    # ./beefcake/meshtasticd.nix
    # ./beefcake/mmrelay.nix
    ./beefcake/immich.nix
    ./beefcake/stalwart.nix
    ./beefcake/bulwark.nix
    ./beefcake/jmap-matrix-notify
    ./beefcake/disk-alerts.nix
    ./beefcake/disk-identification.nix
    ./beefcake/lan-lockdown.nix
    ./beefcake/dns-primary.nix # active hidden DNS primary for lyte.dev (pebble = secondary)

    # ./beefcake/actual.nix
    ./beefcake/factorio-servers.nix
    # ./beefcake/conduwuit.nix
    ./beefcake/tuwunel.nix
    ./beefcake/element-web.nix
    ./beefcake/arr.nix
    ./beefcake/spacetimedb.nix
    ./beefcake/cdn.nix
    ./beefcake/samba.nix
    ./beefcake/syncthing.nix
    ./beefcake/roms.nix
    ./beefcake/miyoo-retrodeck-mirror.nix
    # ./beefcake/n8n.nix # disabled 2026-06: unused (empty /var/lib/n8n, no workflows) and the uncached 2.25.7 npm build is a slow source compile on every rebuild
    # ./beefcake/happy.nix # retired 2026-06: podman-happy.service kept failing on activation (per Daniel)
    ./beefcake/hearth.nix
    ./beefcake/k3s.nix

    # Matrix bridges
    ./beefcake/heisenbridge.nix
    ./beefcake/mautrix-discord.nix
    # Disabled: as_token not accepted by homeserver (crash-looping since conduwuit is disabled)
    # ./beefcake/mautrix-whatsapp.nix
    # ./beefcake/mautrix-meta-facebook.nix
    # ./beefcake/mautrix-meta-instagram.nix
    ./beefcake/mautrix-slack.nix
    ./beefcake/mautrix-gmessages.nix
    ./beefcake/matrix-hookshot.nix
    ./beefcake/unifi.nix
  ]);

  services.spacetimedb.enable = true;

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "riscv64-linux"
  ];

  /*
    if fans are loud:

    # enable manual fan control
    sudo nix run nixpkgs#ipmitool -- raw 0x30 0x30 0x01 0x00

    # set fan speed to last byte as decimal
    sudo nix run nixpkgs#ipmitool -- raw 0x30 0x30 0x02 0xff 0x00
  */
}
