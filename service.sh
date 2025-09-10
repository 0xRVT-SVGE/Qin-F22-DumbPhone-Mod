#!/system/bin/sh
#
# Qin F22 "Dual Personality" service.sh
# - Switches between dumb mode (no touchscreen, dumb launcher, T9 IME, radios off)
#   and normal mode (touchscreen, stock launcher, Gboard, full display)
# - Controlled by hardware key combos.
# - Logs actions for debugging.
#
# Portable version: should work on other Android phones with hardware keypads,
# but requires adjusting KEYCODES, LAUNCHER, and IME package names.
#

### CONFIGURABLE VARIABLES ###

# Input device for keypad events (detect with `getevent -il | grep -i keypad (or kpd/tpd)`)
KEYPAD_DEV="/dev/input/eventY"

# Touchscreen device node (detect with `getevent -il | grep -i touchscreen (or ts)`)
TOUCHSCREEN_DEV="/dev/input/eventX"

# Store a flag if touchscreen was disabled
LOCKFLAG="/data/local/tmp/touchscreen_disabled.flag"

# Log everything
LOGFILE="/data/local/tmp/touchscreen_log.txt"
: > "$LOGFILE"
exec >> "$LOGFILE" 2>&1

# Device major/minor for touchscreen (check with `ls -l /dev/input/eventX` crw------- 1 root root 13, 64 2025-09-09 10:00 event0 the major is 13 and minor 64)
MAJOR=13
MINOR=67

# IMEs (adjust for your system)
IME_ENABLED="com.google.android.inputmethod.latin/com.android.inputmethod.latin.LatinIME"
IME_DISABLED="io.github.sspanak.tt9/.ime.TraditionalT9"

# Launchers (adjust for your system)
LAUNCHER_ENABLED="com.android.launcher3/.Launcher"
LAUNCHER_DISABLED="com.rubenzoet.dumbphonelauncher/.MainActivity"

# Display profiles
SIZE_DISABLED="240x320"
DENSITY_DISABLED=104

### STATE VARIABLES (change if needed, don't forget to also change in main loop) ###
KEY3=0
KEY6=0
VIDEOMODE=0
KEY1=0
KEY4=0
POUND=0
TOTAL_KEYS=0
SCREEN_TURNED_BY_SCRIPT=0
LAST_ACTION=""

### INIT SECTION ###

# Small delay to let post-fs-data finish
sleep 2

# Disable touchscreen at boot if it exists
if [ ! -e "$TOUCHSCREEN_DEV" ] && [ -f "$LOCKFLAG" ]; then
    LAST_ACTION="disabled"
    echo "[INFO] Touchscreen already disabled at boot"
elif [ -e "$TOUCHSCREEN_DEV" ]; then
    rm "$TOUCHSCREEN_DEV"
    touch "$LOCKFLAG"
    echo "[INFO] Touchscreen input disabled after boot"
fi

# Wait for SystemUI so wm/ime operations won't fail
until pidof com.android.systemui > /dev/null; do sleep 1; done
sleep 2

# Apply dumb mode defaults after boot
wm size "$SIZE_DISABLED"
wm density "$DENSITY_DISABLED"
cmd package set-home-activity "$LAUNCHER_DISABLED"
am start -n "$LAUNCHER_DISABLED"
sleep 2
settings put secure default_input_method "$IME_DISABLED"
sleep 1
cmd wifi set-wifi-enabled disabled
service call bluetooth_manager 8
svc data disable
echo "[BOOT] Routine completed successfully"

### FUNCTIONS ###

# Ensures the screen is on before doing mode switches
ensure_screen_on() {
    brightness=$(cat /sys/class/leds/lcd-backlight/brightness)
    if [ "$brightness" -eq 0 ]; then
        input keyevent KEYCODE_WAKEUP
        sleep 0.2
        input keyevent KEYCODE_MENU
        sleep 0.1
        input text 3216    # ⚠️ Replace/remove hardcoded PIN for security
        sleep 0.1
        SCREEN_TURNED_BY_SCRIPT=1
    fi
}

# Switch to enabled (normal) mode
run_enabled() {
    if [ ! -e "$TOUCHSCREEN_DEV" ]; then
        mknod "$TOUCHSCREEN_DEV" c "$MAJOR" "$MINOR"
        chmod 600 "$TOUCHSCREEN_DEV"
        chown root:input "$TOUCHSCREEN_DEV"
    fi
    wm size reset
    wm density reset
    cmd package set-home-activity "$LAUNCHER_ENABLED"
    ensure_screen_on
    ime set "$IME_ENABLED"
    input keyevent KEYCODE_HOME
    if [ "$SCREEN_TURNED_BY_SCRIPT" -eq 1 ]; then
        input keyevent KEYCODE_SLEEP
        SCREEN_TURNED_BY_SCRIPT=0
    fi
    LAST_ACTION="enabled"
    echo "[STATE] Switched to ENABLED"
}

# Switch to disabled (dumb) mode
run_disabled() {
    if [ -e "$TOUCHSCREEN_DEV" ]; then
        rm "$TOUCHSCREEN_DEV"
        touch "$LOCKFLAG"
    fi
    cmd wifi set-wifi-enabled disabled
    service call bluetooth_manager 8
    svc data disable
    cmd package set-home-activity "$LAUNCHER_DISABLED"
    ensure_screen_on
    ime set "$IME_DISABLED"
    input keyevent KEYCODE_HOME
    if [ "$SCREEN_TURNED_BY_SCRIPT" -eq 1 ]; then
        input keyevent KEYCODE_SLEEP
        SCREEN_TURNED_BY_SCRIPT=0
    fi
    sleep 1
    wm size "$SIZE_DISABLED"
    wm density "$DENSITY_DISABLED"
    LAST_ACTION="disabled"
    echo "[STATE] Switched to DISABLED"
}

### MAIN LOOP ###
# Listen for keypad combos and trigger mode switches
while true; do
    timeout 30 getevent -ql "$KEYPAD_DEV" 2>/dev/null | while read -r line; do

        # Track key down/up events to prevent ghost triggers
        case "$line" in
            *KEY_*DOWN*) TOTAL_KEYS=$((TOTAL_KEYS + 1)) ;;
            *KEY_*UP*)
                TOTAL_KEYS=$((TOTAL_KEYS - 1))
                if [ "$TOTAL_KEYS" -lt 0 ]; then TOTAL_KEYS=0; fi
                ;;
        esac

        # Map key events (adjust KEYCODES per device)
        case "$line" in
            *KEY_3*DOWN*)                 KEY3=1 ;;
            *KEY_3*UP*)                   KEY3=0 ;;
            *KEY_6*DOWN*)                 KEY6=1 ;;
            *KEY_6*UP*)                   KEY6=0 ;;
            *KEY_SWITCHVIDEOMODE*DOWN*)   VIDEOMODE=1 ;;
            *KEY_SWITCHVIDEOMODE*UP*)     VIDEOMODE=0 ;;
            *KEY_1*DOWN*)                 KEY1=1 ;;
            *KEY_1*UP*)                   KEY1=0 ;;
            *KEY_4*DOWN*)                 KEY4=1 ;;
            *KEY_4*UP*)                   KEY4=0 ;;
            *KEY_NUMERIC_POUND*DOWN*)     POUND=1 ;;
            *KEY_NUMERIC_POUND*UP*)       POUND=0 ;;
            *) continue ;;
        esac

        # Combo: 3 + 6 + VideoMode → ENABLED
        if [ "$KEY3" -eq 1 ] && [ "$KEY6" -eq 1 ] && [ "$VIDEOMODE" -eq 1 ] &&
           [ "$LAST_ACTION" != "enabled" ] && [ "$TOTAL_KEYS" -le 3 ]; then
            run_enabled
        fi

        # Combo: 1 + 4 + Pound → DISABLED
        if [ "$KEY1" -eq 1 ] && [ "$KEY4" -eq 1 ] && [ "$POUND" -eq 1 ] &&
           [ "$LAST_ACTION" != "disabled" ]; then
            run_disabled
        fi

        # Reset state when no keys are pressed
        if [ "$KEY3" -eq 0 ] && [ "$KEY6" -eq 0 ] && [ "$VIDEOMODE" -eq 0 ] &&
           [ "$KEY1" -eq 0 ] && [ "$KEY4" -eq 0 ] && [ "$POUND" -eq 0 ]; then
            LAST_ACTION=""
            TOTAL_KEYS=0
        fi

        sleep 0.3
    done
done

