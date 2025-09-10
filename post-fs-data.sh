#!/system/bin/sh
#
# Qin F22 "Dual Personality" post-fs-data.sh
# - Runs very early in boot (before system services fully start).
# - Purpose: ensure the touchscreen is disabled *before* Android initializes
#   SystemUI and input stack.
# - Portable version: should work on other Android phones with hardware keypads,
#   but requires adjusting EVENT_DEV and MAJOR/MINOR numbers.
#

### CONFIGURABLE VARIABLES ###

# Touchscreen device node (find with `getevent -il | grep -i touchscreen (or ts)`).
TOUCHSCREEN_DEV="/dev/input/eventX"

# Store a flag if touchscreen was disabled
LOCKFLAG="/data/local/tmp/touchscreen_disabled.flag"

# Log file
LOGFILE="/data/local/tmp/touchscreen_postfs_log.txt"
: > "$LOGFILE"   # Truncate at start
exec >> "$LOGFILE" 2>&1

### SCRIPT START ###

echo "[INFO] post-fs-data.sh started at $(date)"

# Wait up to 60s for the touchscreen device node to appear
timeout=60
count=0
while [ ! -e "$TOUCHSCREEN_DEV" ] && [ "$count" -lt "$timeout" ]; do
    sleep 1
    count=$((count + 1))
done

# If touchscreen exists, disable it by removing the device node
# (⚠️ some kernels may recreate it automatically — in that case, prefer chmod 000)
if [ -e "$TOUCHSCREEN_DEV" ]; then
    rm "$TOUCHSCREEN_DEV"
    touch "$LOCKFLAG"
    echo "[INFO] Touchscreen input disabled"
else
    echo "[WARN] Touchscreen device not found after $timeout seconds"
fi

echo "[INFO] post-fs-data.sh completed at $(date)"
