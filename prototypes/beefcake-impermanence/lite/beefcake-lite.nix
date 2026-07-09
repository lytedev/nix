# beefcake-lite: the REAL beefcake configuration booted as a VM, minus the
# RAM hogs, with dummy secrets. Applied via extendModules on the actual
# nixosConfigurations.beefcake — nothing about the production module set is
# re-declared; this file only overrides what a VM on dragon requires.
#
# This IS the production validation tier, prototyped: candidate closure,
# synthetic (empty) state, throwaway secrets, egress-cut network. Run via
# lite/run-lite.sh.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];

  virtualisation = {
    memorySize = 24 * 1024;
    cores = 12;
    graphics = false;
    diskSize = 60 * 1024;
    diskImage = "./beefcake-lite.qcow2";
  };

  # ---- storage: no zstorage in the VM ----
  boot.zfs.extraPools = lib.mkForce [ ];
  # qemu-vm's mkVMOverride already discards the hardware fileSystems
  # (ext4 root, ESP, zstorage/nix). The dataset mountpoints become plain
  # dirs on the VM disk; owners follow what the modules expect.
  systemd.tmpfiles.rules = [
    "d /storage 0755 root root -"
    "d /storage/postgres 0700 postgres postgres -"
    "d /storage/postgres-backups 0700 postgres postgres -"
    "d /storage/stalwart 0750 stalwart stalwart -"
    # tuwunel is DynamicUser and mkdirs inside — sticky-writable in the VM
    # (the real dataset is owned imperatively)
    "d /storage/tuwunel 1777 root root -"
    "d /storage/tuwunel-backups 1777 root root -"
    "d /storage/forgejo 0750 git gitea -"
    "d /storage/matrix-hookshot 0750 matrix-hookshot matrix-hookshot -"
    "d /storage/kanidm 0700 kanidm kanidm -"
    "d /storage/immich 0750 immich immich -"
    "d /storage/jellyfin 0750 jellyfin jellyfin -"
    "d /storage/audiobookshelf 0750 audiobookshelf audiobookshelf -"
    "d /storage/paperless 0750 paperless paperless -"
    "d /storage/vaultwarden 0750 vaultwarden vaultwarden -"
    "d /storage/vaultwarden/backups 0750 vaultwarden vaultwarden -"
    "d /storage/openobserve 0755 root root -"
    "d /storage/openobserve/data 0755 root root -"
    "d /storage/syncthing 0700 syncthing syncthing -"
    "d /storage/spacetimedb 0750 spacetimedb spacetimedb -"
    "d /storage/k3s 0755 root root -"
    "d /storage/files.lyte.dev 0755 root root -"
    "d /storage/family 0775 root root -"
    "d /storage/valerie 0775 root root -"
    "d /storage/daniel 0775 root root -"
    "d /storage/public 0775 root root -"
    "d /storage/backups 0755 root root -"
    "d /storage/backups/local 0700 root root -"
    "d /storage/backups/canary 0755 root root -"
    "d /storage/flanilla 0755 root root -"
    "d /storage/flanilla-creative 0755 root root -"
    "d /storage/jonland 0755 root root -"
    "d /storage/prom2 0755 root root -"
    "d /storage/miyoo-mini 0755 root root -"
    "d /storage/miyoo-mini/saves 0755 root root -"
    "d /srv/h.lyte.dev 0755 daniel users -"
    "d /run/gitea-runner-cache 1777 root root -"
    # mosquitto-pre-start writes a hashed passwd file into its state dir as the
    # mosquitto user; the stateless tier leaves /var/lib/mosquitto absent/unowned
    # so the touch fails and it start-limit-hits. Create it owned by mosquitto.
    "d /var/lib/mosquitto 0700 mosquitto mosquitto -"
  ];

  # ---- secrets: dummies encrypted to the prototype test key ----
  sops.defaultSopsFile = lib.mkForce ./dummy-secrets.yml;
  # sops-nix rejects store-path keyFiles by type; place the test key in /run
  # during activation, ordered before setupSecrets.
  sops.age.keyFile = lib.mkForce "/run/dummy-age-key.txt";
  sops.age.sshKeyPaths = lib.mkForce [ ];
  sops.gnupg.sshKeyPaths = lib.mkForce [ ];
  system.activationScripts.placeDummyAgeKey = lib.stringAfter [ "specialfs" ] ''
    install -D -m 400 ${../keys/age-test-key.txt} /run/dummy-age-key.txt
  '';
  system.activationScripts.setupSecrets.deps = [ "placeDummyAgeKey" ];
  # secrets whose modules set sopsFile explicitly (not via defaultSopsFile):
  sops.secrets =
    lib.genAttrs
      [
        "headscale-server-authkey"
        "kanidm-persons-migration"
        "kanidm-service-accounts-migration"
        "openobserve-otel.env"
        "syncthing-gui-password"
      ]
      (_: {
        sopsFile = lib.mkForce ./dummy-secrets.yml;
      });

  # ---- empty-state shims (production/clone state would provide these) ----
  # kanidm BindReadOnlyPaths the caddy-copied cert; self-sign a stand-in.
  systemd.services = lib.mkMerge [
    (lib.genAttrs
      [
        "backup-canary-write"
        "backup-canary-read"
        "copy-kanidm-certificates-from-caddy"
        "copy-stalwart-certificates-from-caddy"
        "forgejo-github-mirror"
        "build-lytedev-flake"
        "tailscaled-autoconnect"
        # backup of vaultwarden data — none in the stateless tier; the unit runs
        # at boot (independent of its also-disabled timer) and cp-fails on an
        # empty state dir. Same class as the restic backups disabled below.
        "backup-vaultwarden"
        # factory-fresh chicken-and-egg: the plan-apply polls the JMAP/mgmt
        # port that only the applied plan would configure; production state
        # pre-exists so this never runs from factory there
        "stalwart-apply"
        # state/hardware-coupled (provable only against cloned state / real hw):
        "matrix-hookshot"
        "mautrix-discord"
        "mautrix-slack"
        "mautrix-gmessages"
        "meshtasticd"
        "meshtasticd-provision"
        "wyoming-faster-whisper-hearth"
      ]
      (_: {
        enable = lib.mkForce false;
      })
    )
    {
      # fresh-instance stalwart initializes its FACTORY default config, which
      # includes an https listener on :443 (production shed it at migration);
      # let caddy win the port — stalwart tolerates the failed extra bind.
      stalwart = {
        after = [ "caddy.service" ];
        wants = [ "caddy.service" ];
      };
      # same first-boot race class as atuin (crashes into start-limit before
      # its DBs are up; production DBs are long-lived)
      plausible = {
        after = [
          "postgresql.service"
          "postgresql-setup.service"
          "clickhouse.service"
        ];
        wants = [
          "postgresql.service"
          "clickhouse.service"
        ];
        # ordering alone is not enough: clickhouse's UNIT being started !=
        # clickhouse accepting connections, and plausible's migrations burn
        # the default start-limit in that gap. Retry until the world is up.
        serviceConfig = {
          Restart = lib.mkForce "on-failure";
          RestartSec = lib.mkForce 10;
        };
        unitConfig.StartLimitIntervalSec = lib.mkForce 0;
      };
      # first-boot race: atuin connects before postgresql-setup created its
      # role (production DB pre-exists; only synthetic first boots see this)
      atuin = {
        after = [ "postgresql-setup.service" ];
        wants = [ "postgresql-setup.service" ];
      };
      # Kanidm provisions the OAuth2 clients on its own schedule; on the slow
      # VM that can exceed this fetcher's internal ~9min poll, so it gives up
      # ("client not provisioned?") on the race. Retry-until-up (same pattern
      # as plausible) so it converges once Kanidm has created the clients.
      # Live, the clients pre-exist and it resolves on the first try.
      kanidm-oauth2-secrets = {
        serviceConfig.Restart = lib.mkForce "on-failure";
        serviceConfig.RestartSec = lib.mkForce 15;
        unitConfig.StartLimitIntervalSec = lib.mkForce 0;
      };
      kanidm-dummy-cert = {
        wantedBy = [ "multi-user.target" ];
        before = [
          "kanidm.service"
          "stalwart.service"
        ];
        requiredBy = [
          "kanidm.service"
          "stalwart.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ pkgs.openssl ];
        script = ''
          mkdir -p /storage/kanidm/certs
          if [ ! -f /storage/kanidm/certs/idm.h.lyte.dev.crt ]; then
            openssl req -x509 -newkey rsa:2048 -nodes -days 7 \
              -subj "/CN=idm.h.lyte.dev" \
              -keyout /storage/kanidm/certs/idm.h.lyte.dev.key \
              -out /storage/kanidm/certs/idm.h.lyte.dev.crt
            chown -R kanidm:kanidm /storage/kanidm
          fi
          # stalwart's TLS listeners need fullchain/privkey at its certDir
          # (production copies these from caddy; that unit is masked here)
          mkdir -p /storage/stalwart/certs
          if [ ! -f /storage/stalwart/certs/fullchain.pem ]; then
            openssl req -x509 -newkey rsa:2048 -nodes -days 7 \
              -subj "/CN=mail.lyte.dev" \
              -keyout /storage/stalwart/certs/privkey.pem \
              -out /storage/stalwart/certs/fullchain.pem
            chown -R stalwart:stalwart /storage/stalwart/certs || true
            chmod 600 /storage/stalwart/certs/*
          fi
        '';
      };
    }
  ];
  # roles/DBs that exist imperatively in production postgres:
  services.postgresql.ensureDatabases = [
    "atuin"
    "plausible"
  ];
  services.postgresql.ensureUsers = [
    {
      name = "atuin";
      ensureDBOwnership = true;
    }
    {
      name = "plausible";
      ensureDBOwnership = true;
    }
  ];

  # ---- RAM hogs OFF ----
  virtualisation.oci-containers.containers.minecraft-prom2.autoStart = lib.mkForce false;
  services.immich.machine-learning.enable = lib.mkForce false;
  # wyoming faster-whisper loads multi-GB models; keep the units but the
  # small model. (If this still hurts, disable wyoming entirely.)

  # ---- TIER-0 ALL-GREEN: every unit either succeeds or is structurally
  # absent in this tier. The disable list below IS the production
  # validation-slot mask (egress-coupled jobs, hardware-coupled daemons,
  # state-coupled bridges) — written once here, reused there. Gate:
  # lite/assert-green.sh asserts is-system-running == running.

  # egress-coupled periodic jobs and daemons (incl. the restic-prune-on-real-
  # repos hazard class):
  services.restic.backups = lib.mkForce { };
  services.deno-netlify-ddns-client.enable = lib.mkForce false;
  lyte.dns-updater.enable = lib.mkForce false;
  services.gitea-actions-runner.instances = lib.mkForce { };
  # (disable-set merged into the systemd.services mkMerge above)
  systemd.timers =
    lib.genAttrs
      [
        "backup-canary-write"
        "backup-canary-read"
        "copy-kanidm-certificates-from-caddy"
        "copy-stalwart-certificates-from-caddy"
        "forgejo-github-mirror"
        "build-lytedev-flake"
        # timer-triggered backup of vaultwarden data — none exists in the
        # stateless tier, so it fires at boot and cp-fails on an empty state
        # dir. Same class as the restic backups already disabled.
        "backup-vaultwarden"
      ]
      (_: {
        enable = lib.mkForce false;
      });
  services.smartd.enable = lib.mkForce false;
  services.heisenbridge.enable = lib.mkForce false;
  # no zstorage pool in the VM -> nothing to scrub/snapshot
  services.zfs.autoScrub.enable = lib.mkForce false;
  services.zfs.autoSnapshot.enable = lib.mkForce false;

  # state-coupled containers (image is deploy-pushed / device-coupled):
  virtualisation.oci-containers.containers.hearth.autoStart = lib.mkForce false;
  virtualisation.oci-containers.containers.mmrelay.autoStart = lib.mkForce false;

  # containers whose images we pre-seed so their units PROVE out offline:
  virtualisation.oci-containers.containers.bulwark.imageFile = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/bulwarkmail/webmail";
    imageDigest = "sha256:532fc75982a82706027cb0509db18123a9d1dc19523afa4f4b859352d6add20d";
    finalImageName = "ghcr.io/bulwarkmail/webmail";
    finalImageTag = "1.7.2";
    hash = "sha256-2EwEXRz+tneCcj1i9bZswhEHXdX1wxaFX0p0simfuzs=";
  };
  virtualisation.oci-containers.containers.music-assistant.imageFile = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/music-assistant/server";
    imageDigest = "sha256:eef3ee7810d0e4702afa4a0ff55b10bbbfcaa16c98a277fe1b7f4cb6d5d426b4";
    finalImageName = "ghcr.io/music-assistant/server";
    finalImageTag = "2.8.7";
    hash = "sha256-W13xYM7kNymtEsgUAup4hOlkgot/t6ucJ3M5L0nN6xg=";
  };
  virtualisation.oci-containers.containers.openobserve.imageFile = pkgs.dockerTools.pullImage {
    imageName = "public.ecr.aws/zinclabs/openobserve";
    imageDigest = "sha256:35d2b390321589d88321b421c18117a9df4720f4db3d5c7133976ef09dc25089";
    finalImageName = "public.ecr.aws/zinclabs/openobserve";
    finalImageTag = "v0.70.2";
    hash = "sha256-va7FRqKtOWc4+z6UvV4BCDH7mATwTJq1tpbfefZh77M=";
  };

  # k3s fully offline via its airgap image bundle:
  services.k3s.images = [ config.services.k3s.package.airgap-images ];

  # ---- debuggability ----
  services.getty.autologinUser = lib.mkForce "root";
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../keys/demo-ssh-key.pub ];
  # beefcake's sshd config stands; root key login suffices for the probe.

  # The gitea-runner 32G tmpfs is discarded with the rest of fileSystems by
  # the VM override; the tmpfiles rule above recreates the path as a dir.
}
