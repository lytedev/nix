#!/bin/sh
# ROM Sync - syncs ROMs (pull) and saves (bidirectional) via rsync over SSH.
# Uses a bundled static dbclient (dropbear SSH client) with key auth.

sysdir=/mnt/SDCARD/.tmp_update
export PATH="$sysdir/bin:$PATH"
SD=/mnt/SDCARD
APPDIR="$(cd "$(dirname "$0")" && pwd)"
echo "=== sync.sh started $(date) ==="

. "$APPDIR/config.sh"

export HOME="$APPDIR"
DBCLIENT="$APPDIR/bin/dbclient"
ROM_KEY="$APPDIR/bin/miyoo_rom_key"
SAVE_KEY="$APPDIR/bin/miyoo_save_key"
ROM_SSH="$DBCLIENT -i $ROM_KEY"
SAVE_SSH="$DBCLIENT -i $SAVE_KEY"
ROM_REMOTE="miyoo-sync@$SYNC_HOST"
SAVE_REMOTE="miyoo-sync@$SYNC_HOST"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

bail() {
    echo "ERROR: $1"
    exit 1
}

echo "=== ROM Sync ==="
echo ""

# Test connectivity (use a dry-run rsync listing since rrsync blocks non-rsync commands)
echo "Connecting to $SYNC_HOST..."
if ! rsync --dry-run -e "$ROM_SSH" "$ROM_REMOTE:./" > /dev/null 2>&1; then
    bail "Cannot reach $SYNC_HOST - is WiFi on?"
fi
echo "Connected!"
echo ""

# Correct the clock before syncing: the Mini's RTC can reset/drift, and save
# sync uses rsync --update (newer-mtime-wins), so a wrong clock silently drops
# save uploads. NTP by IP because this LAN's DNS doesn't resolve public names.
# Best-effort — skipped silently if no NTP server is reachable.
printf "${BLUE}[0/4] Syncing clock...${NC}\n"
if ntpdate -b -u 162.159.200.123 216.239.35.0 >/dev/null 2>&1; then
    echo "  clock set: $(date)"
else
    echo "  (skipped - no NTP reachable)"
fi
echo ""

# Push new ROMs (miyoo -> server, add only, cannot delete)
printf "${BLUE}[1/4] Pushing new ROMs...${NC}\n"
rsync -avz --no-owner --no-group -e "$ROM_SSH" \
    "$SD/Roms/" \
    "$ROM_REMOTE:./"
echo ""

# Pull ROMs (server -> miyoo)
printf "${BLUE}[2/4] Pulling ROMs...${NC}\n"
rsync -avz --no-owner --no-group -e "$ROM_SSH" \
    "$ROM_REMOTE:./" \
    "$SD/Roms/"
echo ""

# Push saves (miyoo -> server, newer wins)
printf "${BLUE}[3/4] Pushing saves...${NC}\n"
rsync -avz --no-owner --no-group --update -e "$SAVE_SSH" \
    "$SD/Saves/CurrentProfile/saves/" \
    "$SAVE_REMOTE:saves/"
echo ""

# Pull saves (server -> miyoo, newer wins)
printf "${BLUE}[4/4] Pulling saves...${NC}\n"
rsync -avz --no-owner --no-group --update -e "$SAVE_SSH" \
    "$SAVE_REMOTE:saves/" \
    "$SD/Saves/CurrentProfile/saves/"

# Optionally sync save states
if [ "$SYNC_STATES" = "1" ]; then
    echo ""
    printf "${BLUE}[+] Syncing save states...${NC}\n"
    rsync -avz --no-owner --no-group --update -e "$SAVE_SSH" \
        "$SD/Saves/CurrentProfile/states/" \
        "$SAVE_REMOTE:states/"
    rsync -avz --no-owner --no-group --update -e "$SAVE_SSH" \
        "$SAVE_REMOTE:states/" \
        "$SD/Saves/CurrentProfile/states/"
fi

echo ""
echo "Done!"
echo "=== sync.sh finished $(date) ==="
