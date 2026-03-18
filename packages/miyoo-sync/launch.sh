#!/bin/sh
# ROM Sync - OnionOS app entry point
export sysdir=/mnt/SDCARD/.tmp_update
export PATH="$sysdir/bin:$PATH"
APPDIR="$(dirname "$0")"
cd "$APPDIR"

touch /tmp/stay_awake
infoPanel --title "ROM Sync" --message "Syncing..." --auto &
PANEL_PID=$!

sh ./sync.sh > ./sync.log 2>&1
RC=$?

kill $PANEL_PID 2>/dev/null

if [ $RC -eq 0 ]; then
    infoPanel --title "ROM Sync" --message "Sync complete!"
else
    infoPanel --title "ROM Sync" --message "Sync had errors, check sync.log"
fi

rm -f /tmp/stay_awake
