# P4-integration: the OUTER "thin host" VM — beefcake-host's stack in miniature,
# now running the SHARED production builders (packages/hosts/beefcake/
# slot-domain.nix + cutover-tool.nix) so the nested test exercises exactly the
# code production ships:
#   - TWO slots (mini-blue autostart-able, mini-green defined on demand by the
#     cutover tool) with the Phase-4 persist architecture: a SHARED persist
#     zvol (pool "bpersist") as vdb on whichever slot is active; validation
#     boots a CLONE of it + clones of the share dataset on the isolated
#     egress-cut "validate" network.
#   - dnsmasq on br0 plays the router's service-IP reservation.
# Driven by thinhost-demo.nix: image -> zvols -> migration recipe -> blue up ->
# validate -> validate-done -> cutover -> state-traveled assert -> rollback.
{ nixvirt }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceMac = "b8:ca:3a:6d:2d:24"; # private-bridge only; never the LAN
  mkSlotDomain = import ./slot-domain.nix { inherit nixvirt pkgs; };
  prodShares = [
    {
      srcDir = "/t-storage";
      tag = "storage";
    }
  ];
  validateShares = [
    {
      srcDir = "/t-storage-validate";
      tag = "storage";
    }
  ];
  mkMiniSlot =
    {
      slot,
      uuid,
      mac,
      bridge,
      shares,
      persist,
    }:
    mkSlotDomain {
      name = "mini-${slot}";
      inherit
        uuid
        mac
        bridge
        shares
        ;
      memoryGiB = 3;
      vcpus = 2;
      osVol = "/dev/zvol/rpool/mini-${slot}";
      persistVol = persist;
    };
  blueDomain = mkMiniSlot {
    slot = "blue";
    uuid = "d0000000-beef-cafe-0000-000000000001";
    mac = serviceMac;
    bridge = "br0";
    shares = prodShares;
    persist = "/dev/zvol/rpool/mini-persist";
  };
  greenProdXML = nixvirt.lib.domain.writeXML (mkMiniSlot {
    slot = "green";
    uuid = "d0000000-beef-cafe-0000-000000000002";
    mac = serviceMac;
    bridge = "br0";
    shares = prodShares;
    persist = "/dev/zvol/rpool/mini-persist";
  });
  greenValidateXML = nixvirt.lib.domain.writeXML (mkMiniSlot {
    slot = "green";
    uuid = "d0000000-beef-cafe-0000-000000000002";
    mac = "b8:ca:3a:6d:2d:99";
    bridge = "virbr-validate";
    shares = validateShares;
    persist = "/dev/zvol/rpool/mini-persist-validate";
  });
  mini-cutover = import ./cutover-tool.nix {
    inherit pkgs greenProdXML greenValidateXML;
    toolName = "mini-cutover";
    slotPrefix = "mini";
    shareDatasets = [
      {
        dataset = "rpool/t-storage";
        validateMountpoint = "/t-storage-validate";
      }
    ];
    persistZvolDataset = "rpool/mini-persist";
    markerPath = "/root/active-slot";
  };
in
{
  system.stateVersion = "24.05";
  networking.hostName = "thinhost";
  networking.hostId = "aa11bb22";

  virtualisation = {
    memorySize = 10 * 1024;
    cores = 8;
    graphics = false;
    diskImage = "./thinhost.qcow2";
    # /dev/vdb: becomes the outer rpool (slot OS zvols + persist zvol + share ds)
    emptyDiskImages = [ 40960 ];
    qemu.options = [ "-cpu host" ]; # nested KVM
    sharedDirectories.guestimg = {
      source = "/tmp/thinhost-guest-img";
      target = "/guest-img";
    };
  };

  boot.supportedFilesystems = [ "zfs" ];

  # ---- the stack under test (mirrors beefcake-host.nix) ----
  virtualisation.libvirtd = {
    enable = true;
    qemu.runAsRoot = false;
    qemu.swtpm.enable = true;
    onShutdown = "shutdown";
    qemu.vhostUserPackages = [ pkgs.virtiofsd ];
  };
  virtualisation.libvirt = {
    enable = true;
    connections."qemu:///system" = {
      domains = [
        {
          # define-only: zvols don't exist until the driver provisions them
          active = null;
          definition = nixvirt.lib.domain.writeXML blueDomain;
        }
      ];
      networks = [
        {
          active = true;
          definition = nixvirt.lib.network.writeXML {
            name = "validate";
            uuid = "c0000000-beef-cafe-0000-0000000000aa";
            bridge.name = "virbr-validate";
            # no <forward> -> isolated/egress-cut (mirrors production)
          };
        }
      ];
    };
  };

  networking.bridges.br0.interfaces = [ ];
  networking.interfaces.br0.ipv4.addresses = [
    {
      address = "10.99.0.1";
      prefixLength = 24;
    }
  ];
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "br0";
      bind-interfaces = true;
      dhcp-range = "10.99.0.50,10.99.0.150";
      dhcp-host = "${serviceMac},10.99.0.9";
    };
  };
  networking.firewall.enable = false;

  systemd.tmpfiles.rules = [
    "d /root/.ssh 0700 root root -"
    "C+ /root/.ssh/id_ed25519 0600 root root - ${./keys/demo-ssh-key}"
  ];

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keyFiles = [ ./keys/demo-ssh-key.pub ];
  services.getty.autologinUser = "root";
  environment.systemPackages = [
    pkgs.libvirt
    pkgs.zfs
    mini-cutover
  ];
}
