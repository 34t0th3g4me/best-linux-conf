#!/usr/bin/env bash
# waybar-notifications.sh — emit JSON for waybar custom/notifications.
# Shows the current mako notification count and Do-Not-Disturb state.
# `dnd-toggle` argument toggles DND and refreshes the module.
set -euo pipefail

case "${1:-count}" in
    dnd-toggle)
        if command -v makoctl >/dev/null 2>&1; then
            makoctl mode -t dnd 2>/dev/null || true
        fi
        # Re-emit the count after toggle
        ;&
    count|"")
        if ! command -v makoctl >/dev/null 2>&1; then
            printf '{"text":"-","tooltip":"makoctl not installed","class":"none"}\n'
            exit 0
        fi

        # count = total - dismissed
        total=$(makoctl list 2>/dev/null | grep -c '^Notification' || true)
        dnd=$(makoctl mode 2>/dev/null | grep -q 'dnd: enabled' && echo "yes" || echo "no")

        if [ "$dnd" = "yes" ]; then
            printf '{"text":"%s","tooltip":"Do Not Disturb on","class":"dnd"}\n' "$total"
        elif [ "$total" -gt 0 ]; then
            printf '{"text":"%s","tooltip":"%s notification(s)","class":"none"}\n' "$total" "$total"
        else
            printf '{"text":"","tooltip":"No notifications","class":"none"}\n'
        fi
        ;;
    *)
        echo "Usage: $0 {count|dnd-toggle}" >&2
        exit 1
        ;;
esac
