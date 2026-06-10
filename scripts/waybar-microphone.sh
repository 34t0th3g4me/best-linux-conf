#!/usr/bin/env bash
# waybar-microphone.sh — emit JSON for waybar custom/microphone.
# Shows default-source volume and mute state; `toggle` flips mute.
# Refreshed via signal 11 (pkill -RTMIN+11 waybar) and a 5s interval.
set -euo pipefail

if ! command -v wpctl >/dev/null 2>&1; then
    printf '{"text":"","tooltip":"wpctl not installed","class":"none"}\n'
    exit 0
fi

if [ "${1:-status}" = "toggle" ]; then
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle 2>/dev/null || true
    pkill -RTMIN+11 waybar 2>/dev/null || true
    exit 0
fi

vol_line=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null) || {
    printf '{"text":"","tooltip":"No input device","class":"none"}\n'
    exit 0
}

vol=$(printf '%s' "$vol_line" | awk '{printf "%.0f", $2 * 100}')
desc=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null \
    | awk -F'"' '/node.description/ {print $2; exit}')
desc=${desc:-Microphone}

if printf '%s' "$vol_line" | grep -q MUTED; then
    printf '{"text":"🎙 off","tooltip":"%s — muted","class":"muted"}\n' "$desc"
else
    printf '{"text":"🎙 %s%%","tooltip":"%s — %s%%","class":"none"}\n' "$vol" "$desc" "$vol"
fi
