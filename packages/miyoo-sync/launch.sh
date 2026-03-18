#!/bin/sh
# ROM Sync - OnionOS app entry point
export sysdir=/mnt/SDCARD/.tmp_update
export PATH="$sysdir/bin:$PATH"
APPDIR="$(dirname "$0")"
cd "$APPDIR"

touch /tmp/stay_awake
infoPanel --title "Sync ROMs & Saves" --message "Syncing..." --auto &
PANEL_PID=$!

sh ./sync.sh > ./sync.log 2>&1
RC=$?

kill $PANEL_PID 2>/dev/null

if [ $RC -eq 0 ]; then
    infoPanel --title "Sync ROMs & Saves" --message "Sync complete!\n\nPress any button to exit."
else
    infoPanel --title "Sync ROMs & Saves" --message "Sync had errors, check sync.log\n\nPress any button to exit."
fi

rm -f /tmp/stay_awake
