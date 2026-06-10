#!/usr/bin/env bash
# waybar-backlight-slider.sh — zenity-based backlight slider.
# Click action for the #backlight module.
set -euo pipefail

# Find a writable backlight device
device=""
for d in /sys/class/backlight/*; do
    [ -w "$d/brightness" ] || continue
    device="$d"
    break
done

if [ -z "$device" ]; then
    notify-send "Backlight" "No writable backlight device found" 2>/dev/null || true
    exit 1
fi

max=$(cat "$device/max_brightness")
cur=$(cat "$device/brightness")
pct=$(( cur * 100 / max ))

new_pct=$(zenity --scale \
    --title="Backlight" \
    --text="Brightness" \
    --value="$pct" \
    --min-value=1 \
    --max-value=100 \
    --step=1 \
    --width=350 \
    2>/dev/null) || exit 0

# Apply via brightnessctl if available (handles udevadm trigger), else write sysfs directly
if command -v brightnessctl >/dev/null 2>&1; then
    brightnessctl set "${new_pct}%" >/dev/null 2>&1 || true
else
    new_bri=$(( max * new_pct / 100 ))
    echo "$new_bri" | sudo tee "$device/brightness" >/dev/null 2>&1 || \
        echo "$new_bri" > "$device/brightness" 2>/dev/null || true
fi
