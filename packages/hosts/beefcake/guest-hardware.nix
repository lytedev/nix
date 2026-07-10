# beefcake-guest hardware layer (Phase 3, design §2). Applied via
# `beefcake.extendModules { modules = [ ./guest-hardware.nix ]; }` — reuses ALL
# of beefcake's services + impermanence + sops and swaps ONLY the bare-metal
# hardware (packages/hosts/beefcake/hardware.nix) for the libvirt guest:
#   - virtio-blk root (a host zvol) instead of the SSD mirror + mpt3sas HBA
#   - /nix as the proven OverlayFS (RO base + RW per-slot upper) — the
#     overlay-boot M2 mechanism (prototypes/.../overlay-boot-config.nix)
#   - zstorage datasets via virtiofs shares from the host (Model B) — the guest
#     never imports the pool
#   - a virtio NIC; the host tap carries the service MAC (b8:ca:3a:6d:2d:24) so
#     the guest keeps 192.168.0.9 + the v6 GUA via the router reservation
#
# NOT deployed — validated on dragon via the nested beefcake-host prototype.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  # qemu guest agent: the cutover tool's domfsfreeze/thaw (quiesce before
  # validation snapshots — the DD6 sqlite-WAL lesson) needs it in the guest.
  services.qemuGuest.enable = true;

  # ---- undo the bare-metal hardware.nix ----
  # The guest does NOT own zstorage (host shares datasets via virtiofs).
  boot.zfs.extraPools = lib.mkForce [ ];
  # The guest's pool was created by the disko image-build VM under a FOREIGN
  # hostid (the pool keeps its creation hostid forever), so every guest boot
  # must force-import its own root pool. Safe: inside the VM only vda is
  # visible. (Bug #7 — caught in cutover-prep review.)
  boot.zfs.forceImportRoot = true;
  # Serial-less virtio disks have NO /dev/disk/by-id entries, and the initrd's
  # `zpool import` on the default by-id devNodes waits forever (the proven
  # rollback/overlay-boot gotcha). by-path always exists. (Bug #8.)
  boot.zfs.devNodes = "/dev/disk/by-path";
  # Boot/kernel logs to the domain's serial console so `virsh console
  # beefcake-<slot>` on the host is a LIVE boot view (the 2am recovery path).
  # tty0 listed last stays the primary console (VGA screenshots keep working).
  boot.kernelParams = [
    "console=ttyS0,115200"
    "console=tty0"
  ];
  # virtio, not the SAS HBA.
  boot.initrd.availableKernelModules = lib.mkForce [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "sr_mod"
    "sd_mod"
  ];
  # No dual-ESP mirror on a single virtio disk.
  boot.loader.systemd-boot.extraInstallCommands = lib.mkForce "";

  # ---- disks: virtio-blk. Root stays impermanent (impermanence.nix already
  #      mkForces / = rpool/local/root + /persist = rpool/persist); those live
  #      on the guest's OS zvol pool (rpool). We override /boot and /nix. ----
  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };
  # /nix: base closure on rpool/local/nix (the overlay LOWER), overlaid with a
  # per-slot RW upper on rpool/local/nix-upper (the M2 mechanism). Replaces
  # hardware.nix's /nix = zstorage/nix.
  fileSystems."/nix" = lib.mkForce {
    device = "rpool/local/nix";
    fsType = "zfs";
    neededForBoot = true;
  };
  fileSystems."/nix-upper" = {
    device = "rpool/local/nix-upper";
    fsType = "zfs";
    neededForBoot = true;
  };

  # ---- /nix/store OverlayFS ----
  # Bug #16 (found in the burn-in, THE architectural one): the overlay MUST be
  # assembled in the INITRD, not stage-2. Any generation deployed after the
  # image build lands its closure in the UPPER — and initrd-find-nixos-closure
  # resolves init= against /sysroot/nix/store BEFORE stage-2 exists, so an
  # upper-resident generation is unfindable and the guest drops to emergency.
  # (M2 missed it: the test added store paths but never BOOTED a generation
  # from the upper.) /nix and /nix-upper are stage-1 mounts (neededForBoot),
  # so assemble the overlay right after them, before Find-NixOS-closure.
  boot.initrd.kernelModules = [ "overlay" ];
  boot.initrd.systemd.services.overlay-nix-store = {
    description = "Assemble the /sysroot/nix/store overlay (RO base + RW upper) before closure lookup";
    wantedBy = [ "initrd.target" ];
    requires = [
      "sysroot-nix.mount"
      "sysroot-nix\\x2dupper.mount"
    ];
    after = [
      "sysroot-nix.mount"
      "sysroot-nix\\x2dupper.mount"
    ];
    before = [
      "initrd-find-nixos-closure.service"
      "initrd-fs.target"
    ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /sysroot/nix/.store-lower /sysroot/nix-upper/store /sysroot/nix-upper/work
      mount --bind /sysroot/nix/store /sysroot/nix/.store-lower
      mount -t overlay overlay \
        -o lowerdir=/sysroot/nix/.store-lower,upperdir=/sysroot/nix-upper/store,workdir=/sysroot/nix-upper/work \
        /sysroot/nix/store
      echo "overlaid /sysroot/nix/store (lower=base, upper=slot delta)"
    '';
  };

  # Stage-2 assembly kept as an idempotent SAFETY NET (no-ops when the initrd
  # already did it — the findmnt guard) for generations whose initrd predates
  # the initrd unit.
  boot.kernelModules = [ "overlay" ];
  systemd.services.overlay-nix-store = {
    description = "Overlay /nix/store (RO base lower + RW per-slot upper)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "zfs-mount.service"
      "local-fs.target"
    ];
    requires = [ "zfs-mount.service" ];
    before = [ "nix-daemon.service" ];
    path = [ pkgs.util-linux ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euxo pipefail
      if findmnt -n -o FSTYPE /nix/store | tail -n1 | grep -qx overlay; then
        echo "already overlaid"; exit 0
      fi
      mkdir -p /nix/.store-lower /nix-upper/store /nix-upper/work
      mount --bind /nix/store /nix/.store-lower
      mount -t overlay overlay \
        -o lowerdir=/nix/.store-lower,upperdir=/nix-upper/store,workdir=/nix-upper/work \
        /nix/store
    '';
  };

  # ---- zstorage datasets via virtiofs (Model B) — mounted by the tags the host
  #      domain exposes (beefcake-host.nix: storage / containers / varlib-private).
  #      The host datasets carry xattr=sa + posixacl already. ----
  fileSystems."/storage" = {
    device = "storage";
    fsType = "virtiofs";
  };
  fileSystems."/var/lib/containers" = {
    device = "containers";
    fsType = "virtiofs";
  };
  fileSystems."/var/lib/private" = {
    device = "varlib-private";
    fsType = "virtiofs";
  };

  # ---- k3s on virtiofs (bug #15, found live): containerd's overlayfs
  #      snapshotter needs multi-lowerdir overlay mounts, which virtiofs can't
  #      do (single-lower works — podman is fine). Native snapshotter works on
  #      virtiofs; the lost layer-dedup is irrelevant on 21T zstorage. Phase-4
  #      polish: a zvol-backed containerd dir restores real overlayfs. ----
  services.k3s.extraFlags = lib.mkAfter [ "--snapshotter=native" ];

  # ---- Phase 4: /persist lives on the SHARED persist zvol (pool "bpersist"
  #      on vdb), attached to exactly one slot (or a clone, for validation).
  #      Slot OS zvols are disposable pure-OS; identity+state travel with the
  #      persist pool. Created on the host under hostId 541ede55 = the guest's
  #      own, so the initrd import needs no force. ----
  fileSystems."/persist" = lib.mkForce {
    device = "bpersist/persist";
    fsType = "zfs";
    neededForBoot = true;
  };

  # ---- hardware-coupled daemons belong to the HOST now: the guest has only
  #      virtio disks (no SMART), so smartd fails by design in the VM. The
  #      host runs smartd against the real disks (beefcake-host.nix). ----
  services.smartd.enable = lib.mkForce false;

  # ---- networking: the domain gives the guest's virtio NIC the service MAC
  #      (b8:ca:3a:6d:2d:24). Name that NIC "eno1" by MAC so ALL of
  #      beefcake/networking.nix (nat.externalInterface=eno1, tailscale exit
  #      node, the 192.168.0.9 DHCP reservation, hostId 541ede55) applies
  #      UNCHANGED — the guest is beefcake as far as the LAN is concerned. ----
  systemd.network.links."10-eno1" = {
    matchConfig.MACAddress = "b8:ca:3a:6d:2d:24";
    linkConfig.Name = "eno1";
  };
}
