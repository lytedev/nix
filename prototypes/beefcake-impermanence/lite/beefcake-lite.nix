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
  systemd.services.kanidm-dummy-cert = {
    wantedBy = [ "multi-user.target" ];
    before = [ "kanidm.service" ];
    requiredBy = [ "kanidm.service" ];
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
    '';
  };
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

  # ---- debuggability ----
  services.getty.autologinUser = lib.mkForce "root";
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../keys/demo-ssh-key.pub ];
  # beefcake's sshd config stands; root key login suffices for the probe.

  # The gitea-runner 32G tmpfs is discarded with the rest of fileSystems by
  # the VM override; the tmpfiles rule above recreates the path as a dir.
}
