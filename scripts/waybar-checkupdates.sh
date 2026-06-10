#!/usr/bin/env bash
# waybar-checkupdates.sh — emit JSON for waybar custom/updates.
# Detects distro and runs the right update counter.
# Signal-driven: waybar config uses interval=once + signal 9 to refresh.
set -euo pipefail

source /etc/os-release 2>/dev/null || source /usr/lib/os-release 2>/dev/null || true
ID="${ID:-unknown}"

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
