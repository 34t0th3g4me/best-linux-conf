#!/usr/bin/env bash
# waybar-checkupdates.sh — emit JSON for waybar custom/updates.
# Detects distro and runs the right update counter.
# Signal-driven: waybar config uses interval=once + signal 9 to refresh.
set -euo pipefail

source /etc/os-release 2>/dev/null || source /usr/lib/os-release 2>/dev/null || true
ID="${ID:-unknown}"
# Fold derivatives into their family via ID_LIKE
case " ${ID} ${ID_LIKE:-} " in
    *" fedora "*|*" rhel "*) ID="fedora" ;;
    *" arch "*)              ID="arch" ;;
    *" debian "*|*" ubuntu "*) ID="ubuntu" ;;
esac

# `upgrade` opens a terminal running the distro's upgrade command
if [ "${1:-}" = "upgrade" ]; then
    case "$ID" in
        fedora) cmd="sudo dnf upgrade" ;;
        arch)   cmd="sudo pacman -Syu" ;;
        ubuntu) cmd="sudo apt update && sudo apt upgrade" ;;
        *)      notify-send "updates" "unknown distro — update manually" 2>/dev/null || true; exit 0 ;;
    esac
    for term in "${TERMINAL:-}" ghostty foot kitty alacritty gnome-terminal x-terminal-emulator; do
        [ -n "$term" ] || continue
        if command -v "$term" >/dev/null 2>&1; then
            case "$term" in
                gnome-terminal) exec "$term" -- bash -c "$cmd; read -rp 'done — press enter'" ;;
                *)              exec "$term" -e bash -c "$cmd; read -rp 'done — press enter'" ;;
            esac
        fi
    done
    notify-send "updates" "no terminal emulator found" 2>/dev/null || true
    exit 0
fi

count=0
class="none"
tooltip="No updates"

case "$ID" in
    fedora)
        if command -v dnf >/dev/null 2>&1; then
            # `dnf check-update` exits 100 when updates are available.
            count=$(dnf -q check-update 2>/dev/null | grep -c -E '^\S+\s+\S+\s+\S+\s+\S' || true)
        fi
        ;;
    arch|manjaro|endeavouros)
        if command -v checkupdates >/dev/null 2>&1; then
            count=$(checkupdates 2>/dev/null | wc -l)
        fi
        ;;
    ubuntu|debian|pop)
        if command -v apt >/dev/null 2>&1; then
            # `apt list --upgradable` is slow; `apt-get` is faster.
            count=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst ' || true)
        fi
        ;;
    *)
        count=0
        ;;
esac

if [ "$count" -gt 0 ]; then
    class="has-updates"
    tooltip="$count update(s) available"
else
    count=0
    tooltip="System up to date"
fi

# waybar custom module wants printf-safe JSON
printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$count ↑" "$tooltip" "$class"
