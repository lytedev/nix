# Ephemeral root for beefcake — Phase 1/2 of
# lib/doc/beefcake-impermanence-blue-green.md, flag-gated and a strict no-op
# while disabled (CI receipt: flag-off toplevel drvPath is identical to main).
#
# ACTIVATION IS A DANIEL-DRIVEN RUNBOOK, not a plain deploy:
# lib/doc/beefcake-impermanence-runbook.md. Short version: create
# rpool/local/root (+@blank) and rpool/persist, migrate the persist set,
# flip the flag, deploy WITH --boot, reboot. Every pre-flip generation keeps
# booting from the untouched rpool/root — that is the rollback path.
#
# Mechanism receipts (prototypes/beefcake-impermanence/): the initrd rollback
# unit (rollback-demo), persistence semantics incl. unattended sops on a
# wiped root (checks.semantics), and the by-path/systemd-initrd gotchas.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lyte.impermanence;
in
{
  options.lyte.impermanence.enable = lib.mkEnableOption ''
    ephemeral ZFS root (rpool/local/root rolled back to @blank every boot)
    with explicit state under /persist (rpool/persist). Do NOT enable without
    executing lib/doc/beefcake-impermanence-runbook.md — the datasets and the
    migrated state must exist first
  '';

  config = lib.mkIf cfg.enable {
    # Root moves to the NEW (empty-at-@blank) dataset. rpool/root — today's
    # root — is deliberately untouched: old generations reference it via
    # their own fstab and remain bootable from the systemd-boot menu.
    fileSystems."/" = lib.mkForce {
      device = "rpool/local/root";
      fsType = "zfs";
    };
    fileSystems."/persist" = {
      device = "rpool/persist";
      fsType = "zfs";
      neededForBoot = true; # identity must be mounted before activation/sops
    };

    # The proven rollback mechanism (prototype receipt: rollback-demo).
    # postDeviceCommands is a NO-OP under systemd-initrd — this must be a
    # proper initrd unit, hard-wired to the pool import.
    boot.initrd.systemd.enable = true;
    boot.initrd.systemd.services.rollback-root = {
      description = "Rollback rpool/local/root to @blank (impermanence)";
      wantedBy = [ "initrd.target" ];
      requires = [ "zfs-import-rpool.service" ];
      after = [ "zfs-import-rpool.service" ];
      before = [ "sysroot.mount" ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        zfs rollback -r rpool/local/root@blank
        echo "impermanence: rolled rpool/local/root back to @blank"
      '';
    };

    # Rides the same activation reboot: BIOS VT-d is already enabled (iDRAC
    # verified 2026-07-05); this exposes IOMMU groups for the Phase-5 HBA
    # passthrough option. Zero effect on normal operation.
    boot.kernelParams = [ "intel_iommu=on" ];

    # ---- the persist set (design doc §3 / §3b) ----
    # Everything else on / is deliberately disposable and will vanish at
    # every boot. `zfs diff rpool/local/root@blank` = the live audit of
    # anything writing outside this list.
    environment.persistence."/persist" = {
      hideMounts = true;
      files = [
        "/etc/machine-id"
      ];
      directories = [
        # systemd/nix bookkeeping — required for a functioning system
        "/var/lib/nixos"
        "/var/lib/systemd"
        # network identities
        "/var/lib/tailscale"
        "/var/lib/headscale"
        # service state still living on the root fs today (audit 2026-07-01;
        # /var/lib/{containers,private} and /storage are already zstorage
        # datasets and are NOT part of the ephemeral root)
        "/var/lib/hass"
        "/var/lib/clickhouse"
        "/var/lib/knot"
        "/var/lib/mosquitto"
        "/var/lib/unifi"
        "/var/lib/jellyfin"
        "/var/lib/forgejo-db" # sqlite kept on SSD for perf — stays on rpool
        "/var/lib/mautrix-discord"
        "/var/lib/mautrix-slack"
        "/var/lib/mautrix-gmessages"
        "/var/lib/heisenbridge"
        "/var/lib/meshtasticd"
        "/var/lib/jmap-matrix-notify"
        "/var/lib/forgejo-github-mirror"
        "/var/lib/music-assistant"
        "/var/lib/mmrelay"
        "/var/lib/hearth"
        # vaultwarden's StateDirectory is the project's LEGACY name
        # (bitwarden_rs) — verified live 2026-07-08; /var/lib/vaultwarden
        # does not exist
        "/var/lib/bitwarden_rs"
        "/var/lib/kanidm"
        # PERSISTED but deliberately NOT backed up — persistence and backup
        # are different decisions: un-persisted means recreated EVERY BOOT.
        # caddy: losing ACME state per-boot would re-issue ~30 certs per
        # reboot -> Let's Encrypt rate-limit lockout. (Backup exclusion per
        # Daniel 2026-07-01 stands: it IS re-issuable across a disaster.)
        "/var/lib/caddy"
        # k3s keeps supplementary state here even with dataDir=/storage/k3s
        # (578M live per the 2026-07-01 audit)
        "/var/lib/rancher"
        # k3s DEFAULT-path state that ignores dataDir (2026-07-08 live sweep):
        # kubelet pod/volume state + CNI IP allocations
        "/var/lib/kubelet"
        "/var/lib/cni"
        # module-created redis instances (immich/paperless enable their own;
        # RDB dumps = the 2026-06-28 incident file class)
        "/var/lib/redis-immich"
        "/var/lib/redis-paperless"
        # samba TDBs: machine SID / passdb — losing them de-identifies the
        # file server for every client
        "/var/lib/samba"
        # DHCP lease + seen-network continuity
        "/var/lib/NetworkManager"
        # bootstrap-era age key (bitwarden of history: NOT a current sops
        # recipient — .sops.yaml uses the ssh-host-key-derived identity —
        # but 189 bytes of identity insurance is free)
        "/var/lib/sops-nix"
        # disabled bridges whose sqlite should survive a future re-enable
        "/var/lib/mautrix-meta-facebook"
        "/var/lib/mautrix-meta-instagram"
        "/var/lib/mautrix-whatsapp"
        # operator surfaces
        {
          directory = "/root";
          mode = "0700";
        }
        "/home"
        "/srv"
        # logs: journald is capped (1G) + shipped to OpenObserve; persisting
        # keeps local forensics across the crash-reboots where they matter
        "/var/log"
        # restic metadata caches (~57G, one per repo via systemd
        # CacheDirectory=restic-backups-<name> — verified live 2026-07-08):
        # rebuildable, persisted purely so post-reboot backup runs don't
        # re-fetch indexes from the two remote sftp repos
        "/var/cache/restic-backups-local"
        "/var/cache/restic-backups-rascal"
        "/var/cache/restic-backups-benland"
      ];
    };

    # Host keys live on /persist (NOT a bind of /etc/ssh): they must exist
    # before sshd AND they are the sops-nix age identity — sops-nix's default
    # sshKeyPaths follows services.openssh.hostKeys, so this one change keeps
    # every existing secret decryptable with zero re-keying.
    services.openssh.hostKeys = lib.mkForce [
      {
        path = "/persist/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/persist/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };
}
