# P4-integration: the OUTER "thin host" VM — beefcake-host's stack in miniature,
# run as a qemu VM on dragon (nested KVM, like the modelb demo host). Validates
# the ASSEMBLED runtime the real cutover depends on, none of which a build can
# prove:
#   - libvirtd + the NixVirt module actually define + run a domain
#   - the domain shape from packages/hosts/beefcake-host.nix (linux template +
#     explicit OVMF pflash + RAW virtio-blk zvol disk + shared memoryBacking +
#     virtiofs share + bridge tap with the service MAC) boots a real guest
#   - the guest image is provisioned EXACTLY the runbook way: zpool create →
#     zfs create -V → dd the disko image onto the zvol
#   - dnsmasq on br0 plays the router's MAC reservation → the guest lands on
#     its "service IP"
# The inner guest is thinhost-mini-guest.nix (the M2 overlay-/nix image + the
# guest-hardware mechanisms). Driven by thinhost-demo.nix.
{ nixvirt }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceMac = "b8:ca:3a:6d:2d:24"; # safe: exists only on this VM's private bridge
  # Mirrors beefcake-host.nix mkSlotDomain (keep in sync — this is the shape
  # under test).
  base = nixvirt.lib.domain.templates.linux {
    name = "mini-guest";
    uuid = "d0000000-beef-cafe-0000-000000000001";
    memory = {
      count = 3;
      unit = "GiB";
    };
    vcpu.count = 2;
    storage_vol = "/dev/zvol/rpool/mini";
    bridge_name = "br0";
    net_iface_mac = serviceMac;
  };
  miniDomain = base // {
    os = base.os // {
      loader = {
        readonly = true;
        type = "pflash";
        path = "${pkgs.OVMF.fd}/FV/OVMF_CODE.fd";
      };
      nvram = {
        template = "${pkgs.OVMF.fd}/FV/OVMF_VARS.fd";
        path = "/var/lib/libvirt/qemu/nvram/mini-guest.fd";
      };
    };
    memoryBacking = {
      source.type = "memfd";
      access.mode = "shared";
    };
    devices = base.devices // {
      # block/dev/raw data disk only (mirrors beefcake-host.nix; the template's
      # file/qcow2 disk + install cdrom are wrong for a zvol slot)
      disk = map (
        d:
        d
        // {
          type = "block";
          source.dev = "/dev/zvol/rpool/mini";
          driver = d.driver // {
            type = "raw";
          };
        }
      ) (builtins.filter (d: d.device == "disk") base.devices.disk);
      filesystem = [
        {
          type = "mount";
          accessmode = "passthrough";
          driver.type = "virtiofs"; # TYPE, not name — name silently yields 9p
          binary = {
            path = "${pkgs.virtiofsd}/bin/virtiofsd";
            xattr = true;
          };
          source.dir = "/t-storage";
          target.dir = "storage";
        }
      ];
      # headless-server devices (mirrors beefcake-host.nix): the template's
      # spice+GL graphics need DRM render nodes (absent here AND on the real
      # headless host) — strip them; plain VGA + pty serial console.
      graphics = null;
      sound = null;
      audio = null;
      video.model = {
        type = "vga";
        primary = true;
      };
      channel = [
        {
          type = "unix";
          target = {
            type = "virtio";
            name = "org.qemu.guest_agent.0";
          };
        }
      ];
      redirdev = [ ]; # the template's 4 spicevmc USB redirs — spice is gone
      serial = [ { type = "pty"; } ];
      console = [
        {
          type = "pty";
          target.type = "serial";
        }
      ];
    };
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
    # /dev/vdb: becomes the host's rpool (slot zvols live here)
    emptyDiskImages = [ 16384 ];
    qemu.options = [ "-cpu host" ]; # nested KVM for the inner guest
    # the driver script drops the built mini-guest image here
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
    connections."qemu:///system".domains = [
      {
        # define-only: the zvol doesn't exist until the driver provisions it
        # (runbook flow); the driver runs `virsh start` afterwards.
        active = null;
        definition = nixvirt.lib.domain.writeXML miniDomain;
      }
    ];
  };

  # br0 (no physical uplink in the VM) + the "router": dnsmasq reserving the
  # service IP for the service MAC — the 192.168.0.9 reservation in miniature.
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

  # host virtiofs share source, with a marker the guest must see
  systemd.tmpfiles.rules = [
    "d /t-storage 0755 root root -"
    "f+ /t-storage/marker 0644 root root - thin-host-shared-data"
    # nested ssh (thinhost -> guest) uses the repo demo key
    "d /root/.ssh 0700 root root -"
    "C+ /root/.ssh/id_ed25519 0600 root root - ${./keys/demo-ssh-key}"
  ];

  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keyFiles = [ ./keys/demo-ssh-key.pub ];
  services.getty.autologinUser = "root";
  environment.systemPackages = [
    pkgs.libvirt # virsh
    pkgs.zfs
  ];
}
