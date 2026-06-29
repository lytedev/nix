# Physical disk identification on beefcake — by BAY NUMBER, because the locate
# LEDs don't work here.
#
# WHY NO LOCATE LEDS: the LSI SAS2308 HBA was crossflashed to IT mode so ZFS
# gets raw disks. Side effect — iDRAC no longer recognizes it as a Dell
# controller (its Storage page shows "RAC0503: no out-of-band capable
# controllers"), and the Dell expander backplane doesn't expose a *writable*
# enclosure processor (SEP/SES) to the host. So every locate-LED path is dead
# (all verified 2026-06-29):
#   - iDRAC per-drive Identify          -> HBA invisible to iDRAC
#   - ledctl / sg_ses                   -> no /sys/class/enclosure (SES not enumerated)
#   - sas2ircu 0 LOCATE <enc>:<slot> ON -> "SEP write request failed. Cannot perform LOCATE."
#   - smp_utils                         -> SMP has no enclosure-LED function
# Reads work, only LED *writes* fail. (The host-side activity-LED "blink by
# reading the disk" trick technically works but is useless here — the live pool
# keeps ~8 drives flickering, so the target doesn't stand out.)
#
# HOW TO IDENTIFY INSTEAD — by bay + serial. The expander still reports each
# drive's bay over SMP, which the kernel exposes at
# /sys/class/sas_device/end_device-*/bay_identifier. The `disk-bays` command
# (below) prints the bay <-> serial <-> /dev map. Bay layout on this 12+2 bay
# R720xd:
#   bays 0-11 = front 3.5" LFF       bays 12-13 = rear 2.5" flex bay
#
# TO PULL A DISK:
#   1. Find its serial — e.g. `zpool status -L` + the matching by-id, or
#      `smartctl -H /dev/disk/by-id/<scsi-...>` to confirm the failing one.
#   2. `disk-bays` -> read off its BAY.
#   3. Pull that bay. Because a wrong FRONT pull would hit a live pool member,
#      slide the drive out an inch and confirm the printed SERIAL on its label
#      before fully removing it.
#
# (sas2ircu — Broadcom's proprietary HBA tool — also prints this map via
# `sas2ircu 0 DISPLAY` and is handy for HBA firmware info, but it's not packaged
# here since LOCATE doesn't work and the sysfs path above needs no extra tool.)
{ pkgs, ... }:
let
  disk-bays = pkgs.writeShellApplication {
    name = "disk-bays";
    runtimeInputs = with pkgs; [
      util-linux
      gawk
      coreutils
    ];
    text = ''
      # Map each SAS/SATA disk to its physical backplane bay (locate LEDs are
      # unavailable on this crossflashed HBA + Dell expander — see the module
      # header in disk-identification.nix). Sorted by bay number.
      printf "%-5s %-7s %-15s %-8s %-13s %s\n" BAY DEV SERIAL SIZE MODEL SAS_ADDR
      while read -r name serial size model; do
        blk=/sys/block/$name
        sas=$(cat "$blk/device/sas_address" 2>/dev/null || true)
        bay="?"
        for ed in /sys/class/sas_device/end_device-*; do
          if [ "$(cat "$ed/sas_address" 2>/dev/null || true)" = "$sas" ]; then
            bay=$(cat "$ed/bay_identifier" 2>/dev/null || true)
            break
          fi
        done
        printf "%-5s %-7s %-15s %-8s %-13s %s\n" "$bay" "$name" "$serial" "$size" "$model" "$sas"
      done < <(lsblk -dn -o NAME,SERIAL,SIZE,MODEL | awk '$1 ~ /^sd/') | sort -k1 -n
    '';
  };
in
{
  environment.systemPackages = [ disk-bays ];
}
