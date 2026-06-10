#!/usr/bin/env bash
# waybar-reload.sh — send SIGUSR2 to live-reload config + style.
# Bound to a keybind in niri config.
set -euo pipefail
pkill -SIGUSR2 -x waybar 2>/dev/null || {
    echo "waybar is not running" >&2
    exit 1
}
