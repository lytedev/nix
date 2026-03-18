#!/bin/sh
# ROM Sync - OnionOS app entry point
touch /tmp/stay_awake
APPDIR="$(dirname "$0")"
/mnt/SDCARD/.tmp_update/bin/st -q -e sh "$APPDIR/sync.sh"
rm -f /tmp/stay_awake
