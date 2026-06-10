#!/usr/bin/env bash
# theme-switch.sh — switch the active waybar theme and live-reload.
# Usage: theme-switch.sh <tokyo-night|catppuccin|gruvbox>
set -euo pipefail

theme="${1:-}"
if [ -z "$theme" ]; then
    echo "Usage: $0 <tokyo-night|catppuccin|gruvbox>" >&2
    echo "Current active theme:" >&2
    grep -E '^@import url\("style/' "${HOME}/.config/waybar/style.css" 2>/dev/null | sed 's/^/  /' >&2
    exit 1
fi

case "$theme" in
    tokyo-night|catppuccin|gruvbox) ;;
    *)
        echo "Unknown theme: $theme" >&2
        echo "Valid: tokyo-night, catppuccin, gruvbox" >&2
        exit 1
        ;;
esac

css="${HOME}/.config/waybar/style.css"
if [ ! -f "$css" ]; then
    echo "Cannot find $css — run install.sh first" >&2
    exit 1
fi

# Replace second @import line (the theme line) in-place.
# Use a python one-liner for portable in-place edit.
python3 - "$css" "$theme" <<'PY'
import sys, pathlib
path = pathlib.Path(sys.argv[1])
theme = sys.argv[2]
lines = path.read_text().splitlines()
new = []
imported = 0
for line in lines:
    if line.startswith('@import url("style/') and 'base.css' not in line:
        new.append(f'@import url("style/{theme}.css");')
        imported += 1
    else:
        new.append(line)
if imported == 0:
    # No theme line yet — append it
    new.append(f'@import url("style/{theme}.css");')
path.write_text("\n".join(new) + "\n")
PY

echo "Switched to theme: $theme"

# Live-reload waybar
if pgrep -x waybar >/dev/null 2>&1; then
    pkill -SIGUSR2 -x waybar 2>/dev/null || true
    echo "Sent SIGUSR2 to waybar"
else
    echo "waybar not running — change will apply on next start"
fi
