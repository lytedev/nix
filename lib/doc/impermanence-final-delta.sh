#!/usr/bin/env bash
# beefcake impermanence activation — final state delta (runbook Part 3).
# Run BY DANIEL at the activation window, right before `deploy --boot`:
#   ssh root@192.168.0.9 'bash -s' < lib/doc/impermanence-final-delta.sh
#
# Stops every service that writes into the persist set, then re-runs the
# Part-2 rsyncs so /persist is byte-current. Services are NOT restarted —
# the reboot that follows brings the system up on the new root.
set -euo pipefail

echo "== stopping writers of persist-set paths =="
# (units whose state lives under /var/lib on the root fs; /storage-backed
# services like postgres/stalwart/tuwunel/immich keep running — their state
# is on zstorage and unaffected by the root swap)
systemctl stop \
  caddy knot headscale tailscaled home-assistant clickhouse mosquitto \
  unifi jellyfin forgejo mautrix-discord mautrix-slack mautrix-gmessages \
  heisenbridge meshtasticd jmap-matrix-notify vaultwarden kanidm k3s \
  podman-music-assistant podman-mmrelay podman-hearth 2>&1 \
  | grep -v "not loaded" || true
sync

echo "== mounting rpool/persist =="
mkdir -p /mnt/persist
mountpoint -q /mnt/persist || mount -t zfs rpool/persist /mnt/persist

echo "== final delta rsync =="
mkdir -p /mnt/persist/etc/ssh /mnt/persist/var/lib /mnt/persist/var/cache
cp -a /etc/machine-id /mnt/persist/etc/machine-id
cp -a /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.pub \
      /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key.pub \
      /mnt/persist/etc/ssh/
for d in nixos systemd tailscale headscale hass clickhouse knot mosquitto \
         unifi jellyfin forgejo-db mautrix-discord mautrix-slack \
         mautrix-gmessages heisenbridge meshtasticd jmap-matrix-notify \
         forgejo-github-mirror music-assistant mmrelay hearth bitwarden_rs \
         kanidm caddy rancher; do
  if [ -e "/var/lib/$d" ]; then
    rsync -aHAX --delete "/var/lib/$d" /mnt/persist/var/lib/
  else
    echo "  (skipping /var/lib/$d — not present)"
  fi
done
rsync -aHAX --delete /root  /mnt/persist/
rsync -aHAX --delete /home  /mnt/persist/
rsync -aHAX --delete /srv   /mnt/persist/
rsync -aHAX /var/log /mnt/persist/var/
rsync -aHAX --delete /var/cache/restic-backups-local /var/cache/restic-backups-rascal /var/cache/restic-backups-benland /mnt/persist/var/cache/
sync
umount /mnt/persist

echo
echo "== DONE. /persist is current. Next (you, on dragon): =="
echo "     deploy -s --targets '.#beefcake' -- --boot"
echo "   then: ssh root@192.168.0.9 systemctl reboot"
echo "   (services stay down until the reboot — that's expected)"
