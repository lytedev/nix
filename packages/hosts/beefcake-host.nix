# beefcake-host — Phase 3 thin hypervisor (design doc §2, open-Q#4 = libvirt +
# NixVirt). This is the box's REAL OS after the cutover: a deliberately tiny,
# impermanent NixOS host whose only jobs are (1) own the disks, (2) run today's
# beefcake config as a libvirt GUEST, (3) bridge the guest onto the LAN with the
# service MAC. Everything that is "beefcake the service host" lives in the guest.
#
# STATUS: increment 1 — the thin host itself (boot/disk/net/libvirtd/monitoring),
# NOT YET DEPLOYED. Validated on dragon via a nested VM. The GUEST domain
# (beefcake-guest, /nix overlay per overlay-nix M1, zstorage virtiofs shares,
# service-MAC tap) is the NEXT increment; wired in via NixVirt below where marked.
#
# Registered in packages/hosts/default.nix with the impermanence + NixVirt
# modules as extraModules.
{
  config,
  lib,
  pkgs,
  hardware,
  nixvirt,
  ...
}:
let
  # Slot domains + the cutover tool come from the SHARED builders (also used
  # by the nested integration test — test-what-you-ship):
  #   packages/hosts/beefcake/slot-domain.nix   (every domain lesson encoded)
  #   packages/hosts/beefcake/cutover-tool.nix  (validate/cutover/rollback)
  # Phase-4 persist architecture: /persist lives on the SHARED zvol
  # rpool/beefcake-persist (pool "bpersist"), attached as vdb to exactly one
  # slot; validation gets a CLONE. Slot OS zvols are disposable pure-OS.
  serviceMac = "b8:ca:3a:6d:2d:24";
  persistVol = "/dev/zvol/rpool/beefcake-persist";
  mkSlotDomain = import ./beefcake/slot-domain.nix { inherit nixvirt pkgs; };
  prodShares = [
    {
      srcDir = "/storage";
      tag = "storage";
    }
    {
      srcDir = "/var/lib/containers";
      tag = "containers";
    }
    {
      srcDir = "/var/lib/private";
      tag = "varlib-private";
    }
  ];
  validateShares = map (s: s // { srcDir = s.srcDir + "-validate"; }) prodShares;
  mkBeefcakeSlot =
    {
      slot,
      uuid,
      mac,
      bridge,
      shares,
      persist,
    }:
    mkSlotDomain {
      name = "beefcake-${slot}";
      inherit
        uuid
        mac
        bridge
        shares
        ;
      memoryGiB = 200;
      vcpus = 36;
      osVol = "/dev/zvol/rpool/beefcake-${slot}";
      persistVol = persist;
    };
  blueDomain = mkBeefcakeSlot {
    slot = "blue";
    uuid = "b1000000-beef-cafe-0000-000000000001";
    mac = serviceMac;
    bridge = "br0";
    shares = prodShares;
    persist = persistVol;
  };
  greenProdXML = nixvirt.lib.domain.writeXML (mkBeefcakeSlot {
    slot = "green";
    uuid = "b1000000-beef-cafe-0000-000000000002";
    mac = serviceMac; # only ever started with blue stopped (tool enforces)
    bridge = "br0";
    shares = prodShares;
    persist = persistVol;
  });
  greenValidateXML = nixvirt.lib.domain.writeXML (mkBeefcakeSlot {
    slot = "green";
    uuid = "b1000000-beef-cafe-0000-000000000002";
    mac = "b8:ca:3a:6d:2d:99"; # NON-service MAC
    bridge = "virbr-validate"; # isolated, egress-cut
    shares = validateShares; # ZFS clones
    persist = "${persistVol}-validate"; # persist CLONE — full identity, discarded
  });
  beefcake-cutover = import ./beefcake/cutover-tool.nix {
    inherit pkgs greenProdXML greenValidateXML;
    slotPrefix = "beefcake";
    # REAL dataset names (created imperatively 2026-06; verified live) + the
    # explicit mountpoints their validation clones get.
    shareDatasets = [
      {
        dataset = "zstorage/storage";
        validateMountpoint = "/storage-validate";
      }
      {
        dataset = "zstorage/containers";
        validateMountpoint = "/var/lib/containers-validate";
      }
      {
        dataset = "zstorage/varlib-private";
        validateMountpoint = "/var/lib/private-validate";
      }
    ];
    persistZvolDataset = "rpool/beefcake-persist";
  };
in
{
  imports = [
    hardware.common-cpu-intel
  ];

  networking.hostName = "beefcake-host";
  # SAME hostId as bare-metal beefcake (and the guest): zstorage + rpool were
  # last attached under 541ede55 and are NOT exported at shutdown — a different
  # hostId would make the host's imports refuse ("in use from another system").
  # Safe to share: host and guest never import the same pool (the guest only
  # force-imports its own inner zvol pool). Caught in cutover pre-flight.
  networking.hostId = "541ede55";

  # ---- boot / disk: same hardware as beefcake (Dell R720xd), SSD ZFS mirror
  #      root, dual ESPs, HBA + KVM. Mirrors packages/hosts/beefcake/hardware.nix
  #      but WITHOUT declaring /nix on zstorage — the host's /nix rides its own
  #      root pool (tiny closure); zstorage is imported for SHARING to the guest,
  #      not for the host's own /nix. ----
  boot = {
    supportedFilesystems.zfs = true;
    initrd.supportedFilesystems.zfs = true;
    initrd.availableKernelModules = [
      "ehci_pci"
      "mpt3sas" # the one IT-mode HBA driving every disk
      "usbhid"
      "sd_mod"
    ];
    kernelModules = [ "kvm-intel" ];
    # intel_iommu on for the Phase-5 HBA-passthrough option (BIOS VT-d already
    # enabled); harmless otherwise.
    kernelParams = [
      "nohibernate"
      "intel_iommu=on"
    ];
    loader.systemd-boot.enable = true;
    loader.systemd-boot.configurationLimit = 20;
    loader.efi.canTouchEfiVariables = true;
    # Mirror ESP-A onto ESP-B after install so either SSD boots (as beefcake).
    loader.systemd-boot.extraInstallCommands = ''
      espB=/dev/disk/by-partlabel/ESP-B
      if [ -e "$espB" ]; then
        m=$(mktemp -d)
        ${pkgs.util-linux}/bin/mount "$espB" "$m"
        ${pkgs.rsync}/bin/rsync -a --delete /boot/ "$m"/
        ${pkgs.util-linux}/bin/umount "$m"
        rmdir "$m"
      fi
    '';
  };

  # The host root is impermanent on its own rpool dataset. lyte.impermanence
  # (packages/hosts/beefcake/impermanence.nix is beefcake-specific; the host
  # reuses the SAME proven mechanism — @blank rollback initrd unit + /persist).
  # TODO(increment): factor the impermanence.nix mechanism into a shared module
  # so beefcake-host and beefcake(guest) both consume it instead of copying.
  # For now the host's persist set is intentionally tiny (identity + libvirt).
  # The host gets its OWN root + persist datasets (rpool/local/host-root@blank,
  # rpool/host-persist — created in cutover prep), NOT beefcake's
  # rpool/local/root + rpool/persist: sharing persist would hand the host
  # beefcake's machine-id (now the GUEST's identity -> DHCP-DUID collision on
  # the same bridge) and gen-609 fallback must keep its datasets untouched.
  # /nix reuses zstorage/nix exactly like today's beefcake (imported in
  # initrd — proven on this machine; deploy --boot lands the host closure
  # there, so it is populated BEFORE the first host boot; a fresh rpool
  # dataset would be EMPTY at boot). Caught in cutover pre-flight.
  fileSystems = {
    "/" = {
      device = "rpool/local/host-root";
      fsType = "zfs";
    };
    "/persist" = {
      device = "rpool/host-persist";
      fsType = "zfs";
      neededForBoot = true;
    };
    "/boot" = {
      device = "/dev/disk/by-partlabel/ESP-A";
      fsType = "vfat";
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
    };
    "/nix" = {
      device = "zstorage/nix";
      fsType = "zfs";
      neededForBoot = true;
    };
  };

  # The proven impermanence machinery (impermanence.nix + rollback-demo),
  # targeting the HOST's datasets. Wipe host-root to @blank each boot; seed a
  # host-own machine-id (self-generating on first boot -> fresh host identity,
  # distinct from the guest's) before switch-root.
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.services.rollback-host-root = {
    description = "Rollback rpool/local/host-root to @blank (impermanence)";
    wantedBy = [ "initrd.target" ];
    requires = [ "zfs-import-rpool.service" ];
    after = [ "zfs-import-rpool.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = "zfs rollback -r rpool/local/host-root@blank";
  };
  boot.initrd.systemd.services.persist-machine-id = {
    description = "Seed host /etc/machine-id from /persist before switch-root";
    wantedBy = [ "initrd.target" ];
    requires = [
      "sysroot.mount"
      "sysroot-persist.mount"
    ];
    after = [
      "rollback-host-root.service"
      "sysroot.mount"
      "sysroot-persist.mount"
    ];
    before = [ "initrd-switch-root.target" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /sysroot/persist/etc /sysroot/etc
      if [ ! -s /sysroot/persist/etc/machine-id ]; then
        tr -d - < /proc/sys/kernel/random/uuid > /sysroot/persist/etc/machine-id
      fi
      cp /sysroot/persist/etc/machine-id /sysroot/etc/machine-id
      chmod 0444 /sysroot/etc/machine-id
    '';
  };

  # Host ssh identity persists across the root wipe (self-generates into
  # /persist on first boot). The #727 /var-perms guard rides along.
  services.openssh.hostKeys = [
    {
      path = "/persist/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];
  systemd.tmpfiles.rules = [
    "d /var 0755 root root -"
    "d /var/lib 0755 root root -"
    "d /var/cache 0755 root root -"
  ];

  # Host owns zstorage: import it (do NOT mount its datasets on the host beyond
  # what it shares) so the host can virtiofs-share datasets into the guest.
  boot.zfs.extraPools = [ "zstorage" ];

  # ---- networking: br0 enslaves eno1; the guest's virtio NIC rides br0 with
  #      the SERVICE MAC (b8:ca:3a:6d:2d:24) to keep 192.168.0.9 + the v6 GUA.
  #      The HOST takes its own DHCP address ON br0 with a PINNED, distinct MAC
  #      — no eno2 cable required for management (autonomous-cutover req). ----
  networking = {
    useDHCP = false;
    bridges.br0.interfaces = [ "eno1" ];
    # CRITICAL (bug #6, caught in the autonomous-cutover review): a Linux bridge
    # inherits the MAC of its (lowest) enslaved NIC — br0 would come up wearing
    # eno1's burned-in MAC, which IS the service MAC the GUEST carries, and the
    # two would fight over 192.168.0.9 (ARP flapping). Pin br0 a distinct,
    # locally-administered MAC; the router sees the host as its own device and
    # DHCPs it a separate address (reserve it in the router when known).
    interfaces.br0 = {
      macAddress = "0a:be:ef:b0:57:01"; # locally-administered; "beef host 1"
      useDHCP = true;
    };
    # Bug #14 (found live at cutover): pinning br0 is NOT enough — the enslaved
    # eno1 PORT still owns its burned-in MAC, which IS the service MAC the
    # guest carries. The bridge FDB then treats service-MAC frames as local to
    # the port and never forwards them to the guest tap (guest DHCP/ARP die
    # silently). The PHYSICAL port must be re-MAC'd too; the guest is the sole
    # owner of b8:ca:3a:6d:2d:24 on the bridge.
    interfaces.eno1.macAddress = "0a:be:ef:b0:57:0e";
    # eno2/3/4 stay unplugged; plugging eno2 remains an OPTIONAL second mgmt
    # path (interfaces.eno2.useDHCP) but is deliberately not required.
  };

  # ---- virtualization: libvirt + NixVirt (design open-Q#4) ----
  virtualisation.libvirtd = {
    enable = true;
    qemu.runAsRoot = false;
    qemu.swtpm.enable = true;
    onShutdown = "shutdown"; # clean guest poweroff (DD6: never SIGTERM the VMM)
    # DATA-SAFETY (adversarial suite, two-writer scenario): make qemu take
    # virtlockd disk locks. The shared persist zvol must never be opened rw by
    # two slots at once — with lockd, the SECOND domain that references a disk
    # already held by a running domain fails to start. Belt to the cutover
    # tool's single-writer logic (defense in depth: a manual `virsh start` of
    # both slots is refused at the qemu layer, not just by our script).
    qemu.verbatimConfig = ''
      lock_manager = "lockd"
    '';
  };
  # virtiofsd for sharing host zstorage datasets into the guest (Model B).
  virtualisation.libvirtd.qemu.vhostUserPackages = [ pkgs.virtiofsd ];

  # The guest domain, declared (NixVirt). `active` autostarts the blue slot; its
  # OS closure is beefcake-guest (packages/hosts/beefcake/guest-hardware.nix),
  # written to the /dev/zvol/rpool/beefcake-blue disk at cutover. virtiofs shares
  # feed it the host's zstorage datasets; the tap carries the service MAC.
  # (Green slot + the cutover tool are Phase 4.)
  virtualisation.libvirt = {
    enable = true;
    connections."qemu:///system" = {
      domains = [
        {
          active = true; # blue autostarts as the active slot
          definition = nixvirt.lib.domain.writeXML blueDomain;
        }
      ];
      # Isolated, egress-cut network for green validation (no service MAC ever
      # reaches the LAN here). green-production uses br0 directly (not a libvirt
      # network), so this exists only for the validation boot.
      networks = [
        {
          active = true;
          definition = nixvirt.lib.network.writeXML {
            name = "validate";
            uuid = "c0000000-beef-cafe-0000-0000000000aa";
            bridge.name = "virbr-validate";
            # no <forward> → isolated (no NAT/egress); guests talk only to each
            # other + the host. Matches the demo's egress-cut validation slot.
          };
        }
      ];
    };
  };

  # The cutover tool + the active-slot marker (persisted across the host's
  # ephemeral root so an unattended host reboot restarts the right slot).
  environment.systemPackages = [ beefcake-cutover ];

  # ---- monitoring: hardware lives with the host (smartd/IPMI/node-exporter),
  #      shipped to the guest's OpenObserve (design §5). ----
  services.smartd.enable = true;
  hardware.enableRedistributableFirmware = true;

  # ---- minimal: sshd for host access; NO beefcake services (those are the
  #      guest). Host access is the guest-independent recovery path (§5). ----
  services.openssh.enable = true;

  # The host's /persist set is deliberately tiny: its identity + libvirt state
  # + the active-slot marker. (Guest state is the guest's problem.)
  environment.persistence."/persist" = {
    hideMounts = true;
    files = [ ];
    directories = [
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/libvirt" # domain defs / nvram / swtpm state
    ];
  };

  system.stateVersion = "26.05";
}
