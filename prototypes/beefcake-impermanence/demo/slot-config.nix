# A blue/green SLOT for the hands-on demo: a compute-shell guest in the
# Model B shape, running REAL services:
#   - vaultwarden: sqlite state on the 9p-shared dataset (/shared/vaultwarden)
#     — create an account + save entries, then watch them survive cutover.
#     (9p stands in for virtiofs in this demo; semantics proven in P3.)
#   - postgres: dataDir on the zvol attached as /dev/vdb (the zvol-backed
#     directory primitive).
#   - caddy fronting vaultwarden (http; localhost is a secure origin so the
#     web vault's crypto works over the port-forward chain).
#
# Root is tmpfs (diskImage = null): the slot is disposable by construction.
# The slot's closure lives in the (demo-)host's store, shared read-only via
# the VM runner — no per-slot disk image, exactly the DD3 shape.
{ slotName }:
{
  config,
  lib,
  pkgs,
  ...
}:
{
  system.stateVersion = "24.05";
  networking.hostName = "slot-${slotName}";

  virtualisation = {
    diskImage = null; # tmpfs root — impermanent slot
    memorySize = 2048;
    cores = 2;
    graphics = false; # headless under systemd-run in the demo host
  };

  # NOTE: the qemu-vm module mkVMOverride-s plain `fileSystems`, so VM mounts
  # MUST be declared under virtualisation.fileSystems or they silently vanish.
  # /shared <- 9p export "state" from the demo host (state datasets).
  virtualisation.fileSystems."/shared" = {
    device = "state";
    fsType = "9p";
    options = [
      "trans=virtio"
      "version=9p2000.L"
      "msize=1048576"
      "cache=loose"
      "nofail"
    ];
  };

  # The zvol-backed directory: with no root disk image, the host-attached
  # zvol (real or clone) shows up as the FIRST virtio disk, /dev/vda.
  virtualisation.fileSystems."/srv/pg" = {
    device = "/dev/vda";
    fsType = "ext4";
    # no `nofail`: the mount must block local-fs.target so tmpfiles creates
    # /srv/pg/data on the REAL fs, not on tmpfs-under-the-mount. slot-run
    # always attaches the zvol, and if it didn't we want a loud failure.
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    dataDir = "/srv/pg/data";
  };
  # Learned in P2: don't crash-loop before the zvol/mount exists.
  systemd.services.postgresql.unitConfig.ConditionPathExists = "/srv/pg";

  services.vaultwarden = {
    enable = true;
    config = {
      DATA_FOLDER = "/shared/vaultwarden";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      # Demo only: the web vault treats http://localhost as a secure origin.
      DOMAIN = "http://localhost:8080";
    };
  };
  # P2 lesson, applied: ReadWritePaths targets must exist BEFORE namespace
  # setup (preStart runs inside the namespace, too late to create them).
  # tmpfiles runs after mounts and before services — the right place.
  systemd.tmpfiles.rules = [
    "d /shared/vaultwarden 0700 vaultwarden vaultwarden -"
    "d /srv/pg/data 0750 postgres postgres -"
  ];
  systemd.services.vaultwarden = {
    unitConfig.ConditionPathExists = "/shared/vaultwarden";
    serviceConfig.ReadWritePaths = [ "/shared/vaultwarden" ];
  };

  services.caddy = {
    enable = true;
    virtualHosts."http://:8000".extraConfig = ''
      reverse_proxy 127.0.0.1:8222
    '';
  };

  # Identity + banner so it's obvious which slot answered.
  environment.etc."slot".text = slotName;
  users.motd = ''

    ================================================
      SLOT: ${lib.toUpper slotName}
      root is tmpfs (wiped every boot)
      /shared        = 9p share from the demo host
      /srv/pg        = zvol-backed dir (/dev/vdb)
    ================================================
  '';

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };
  users.users.root.openssh.authorizedKeys.keyFiles = [ ../keys/demo-ssh-key.pub ];

  networking.firewall.enable = false; # demo VM behind user-net NAT
}
