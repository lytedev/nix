#!/bin/sh
# ROM Sync - syncs ROMs (pull) and saves (bidirectional) via rsync over SSH.
# Uses a bundled static dbclient (dropbear SSH client) with key auth.

sysdir=/mnt/SDCARD/.tmp_update
export PATH="$sysdir/bin:$PATH"
SD=/mnt/SDCARD
APPDIR="$(cd "$(dirname "$0")" && pwd)"

. "$APPDIR/config.sh"

DBCLIENT="$APPDIR/bin/dbclient"
ROM_KEY="$APPDIR/bin/miyoo_rom_key"
SAVE_KEY="$APPDIR/bin/miyoo_save_key"
ROM_SSH="$DBCLIENT -y -y -i $ROM_KEY"
SAVE_SSH="$DBCLIENT -y -y -i $SAVE_KEY"
ROM_REMOTE="miyoo-sync@$SYNC_HOST"
SAVE_REMOTE="miyoo-sync@$SYNC_HOST"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

bail() {
    printf "${RED}%s${NC}\n" "$1"
    echo ""
    printf "${YELLOW}Press any button to exit.${NC}\n"
    read -n 1 -s -r
    exit 1
}

echo "=== ROM Sync ==="
echo ""

# Test connectivity
echo "Connecting to $SYNC_HOST..."
if ! $DBCLIENT -y -y -i "$ROM_KEY" "$ROM_REMOTE" echo ok > /dev/null 2>&1; then
    bail "Cannot reach $SYNC_HOST with ROM key - is WiFi on?"
fi
if ! $DBCLIENT -y -y -i "$SAVE_KEY" "$SAVE_REMOTE" echo ok > /dev/null 2>&1; then
    bail "Cannot reach $SYNC_HOST - is WiFi on?"
fi
echo "Connected!"
echo ""

# Pull ROMs (server -> miyoo)
printf "${BLUE}[1/3] Pulling ROMs...${NC}\n"
rsync -avz -e "$ROM_SSH" \
    "$ROM_REMOTE:./" \
    "$SD/Roms/"
echo ""

# Push saves (miyoo -> server, newer wins)
printf "${BLUE}[2/3] Pushing saves...${NC}\n"
rsync -avz --update -e "$SAVE_SSH" \
    "$SD/Saves/CurrentProfile/saves/" \
    "$SAVE_REMOTE:saves/"
echo ""

# Pull saves (server -> miyoo, newer wins)
printf "${BLUE}[3/3] Pulling saves...${NC}\n"
rsync -avz --update -e "$SAVE_SSH" \
    "$SAVE_REMOTE:saves/" \
    "$SD/Saves/CurrentProfile/saves/"

# Optionally sync save states
if [ "$SYNC_STATES" = "1" ]; then
    echo ""
    printf "${BLUE}[+] Syncing save states...${NC}\n"
    rsync -avz --update -e "$SAVE_SSH" \
        "$SD/Saves/CurrentProfile/states/" \
        "$SAVE_REMOTE:states/"
    rsync -avz --update -e "$SAVE_SSH" \
        "$SAVE_REMOTE:states/" \
        "$SD/Saves/CurrentProfile/states/"
fi

echo ""
printf "${GREEN}Done! Press any button to exit.${NC}\n"
read -n 1 -s -r
