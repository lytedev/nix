# COPY of packages/hosts/beefcake/slot-domain.nix (the production source
# of truth) — kept in-tree so the standalone prototype flake stays
# self-contained. Keep in sync when the production builder changes.
# mkSlotDomain — the ONE slot-domain builder (Phase 3/4), used by BOTH the
# production thin host (packages/hosts/beefcake-host.nix) and the nested
# integration test (prototypes/beefcake-impermanence/thinhost-config.nix), so
# the test exercises exactly the shape production runs.
#
# Encodes every domain lesson from the cutover + burn-in (bugs #1-#16 class):
# explicit OVMF pflash + per-slot nvram (SeaBIOS can't boot the ESP image);
# block/dev/raw disks (zvols are block devices holding raw images; the
# template's file/qcow2 breaks); virtiofs by driver.TYPE (driver.name silently
# yields 9p); headless devices (spice+GL needs DRM render nodes absent on
# servers) with a pty serial console (the virsh-console recovery path);
# on_crash=restart (a guest panic must not leave the box serviceless);
# shared memoryBacking (virtiofs requirement).
#
# Phase 4: `persistVol` attaches the SHARED persist zvol as vdb — the real one
# for production slots (only one runs at a time; the cutover tool enforces),
# a CLONE for validation slots. Slot OS zvols stay disposable pure-OS.
{ nixvirt, pkgs }:
{
  name,
  uuid,
  memoryGiB,
  vcpus,
  osVol, # /dev/zvol/... holding the slot's OS image (vda)
  persistVol, # /dev/zvol/... holding the persist pool (vdb; real or clone)
  mac,
  bridge,
  # [{ srcDir; tag; }] — virtiofs shares (live datasets or -validate clones)
  shares,
}:
let
  base = nixvirt.lib.domain.templates.linux {
    inherit name uuid;
    memory = {
      count = memoryGiB;
      unit = "GiB";
    };
    vcpu.count = vcpus;
    storage_vol = osVol;
    bridge_name = bridge;
    net_iface_mac = mac;
  };
  blockDisk = dev: target: {
    type = "block";
    device = "disk";
    driver = {
      name = "qemu";
      type = "raw";
      cache = "none";
      discard = "unmap";
    };
    source.dev = dev;
    target = {
      dev = target;
      bus = "virtio";
    };
  };
in
base
// {
  on_crash = "restart";
  os = base.os // {
    loader = {
      readonly = true;
      type = "pflash";
      path = "${pkgs.OVMF.fd}/FV/OVMF_CODE.fd";
    };
    nvram = {
      template = "${pkgs.OVMF.fd}/FV/OVMF_VARS.fd";
      path = "/var/lib/libvirt/qemu/nvram/${name}.fd";
    };
  };
  memoryBacking = {
    source.type = "memfd";
    access.mode = "shared";
  };
  devices = base.devices // {
    disk = [
      (blockDisk osVol "vda")
      (blockDisk persistVol "vdb")
    ];
    filesystem = map (s: {
      type = "mount";
      accessmode = "passthrough";
      driver.type = "virtiofs";
      binary = {
        path = "${pkgs.virtiofsd}/bin/virtiofsd";
        xattr = true;
      };
      source.dir = s.srcDir;
      target.dir = s.tag;
    }) shares;
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
    redirdev = [ ];
    serial = [ { type = "pty"; } ];
    console = [
      {
        type = "pty";
        target.type = "serial";
      }
    ];
  };
}
