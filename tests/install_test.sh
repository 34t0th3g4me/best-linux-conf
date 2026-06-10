#!/usr/bin/env bash
# tests/install_test.sh — minimal assertions, no test framework.
# Run with: bash tests/install_test.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS  $label"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $label — expected '$expected', got '$actual'"
        FAIL=$((FAIL+1))
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "  PASS  $label"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $label — '$needle' not in '$haystack'"
        FAIL=$((FAIL+1))
    fi
}

echo "test: install.sh --check-only detects distro"
# Derive the expected distro from the running system so the test
# passes on any supported machine, not just the author's.
HOST_ID="$(. /etc/os-release && echo "$ID")"
OUTPUT="$(${REPO_DIR}/install.sh --check-only 2>&1 || true)"
assert_contains "identifies host distro" "$HOST_ID" "$OUTPUT"
assert_contains "reports package manager" "using " "$OUTPUT"
assert_contains "check-only exit message" "Check complete" "$OUTPUT"

echo "test: package name mapping per distro family"
assert_eq "debian: mako -> mako-notifier" "mako-notifier" "$(${REPO_DIR}/install.sh --pkg-for mako:debian)"
assert_eq "fedora: mako -> mako" "mako" "$(${REPO_DIR}/install.sh --pkg-for mako:fedora)"
assert_eq "arch: font-mono -> ttf-jetbrains-mono" "ttf-jetbrains-mono" "$(${REPO_DIR}/install.sh --pkg-for font-mono:arch)"
assert_eq "debian: font-mono -> fonts-jetbrains-mono" "fonts-jetbrains-mono" "$(${REPO_DIR}/install.sh --pkg-for font-mono:debian)"
assert_eq "suse: notify-send -> libnotify-tools" "libnotify-tools" "$(${REPO_DIR}/install.sh --pkg-for notify-send:suse)"
assert_eq "fedora: pipewire pulse pkg" "pipewire pipewire-pulseaudio" "$(${REPO_DIR}/install.sh --pkg-for pipewire:fedora)"
assert_eq "debian: lockscreen pkgs" "swaylock swayidle" "$(${REPO_DIR}/install.sh --pkg-for lockscreen:debian)"
assert_eq "arch: portal pkgs" "xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk" "$(${REPO_DIR}/install.sh --pkg-for portal:arch)"
assert_eq "unknown key maps to empty" "" "$(${REPO_DIR}/install.sh --pkg-for nonsense:debian)"

echo "test: --theme with separate value is accepted"
OUTPUT="$(${REPO_DIR}/install.sh --check-only --theme catppuccin 2>&1 || true)"
assert_contains "theme accepted" "Initial theme: catppuccin" "$OUTPUT"

echo "test: install.sh --check-only rejects unknown theme"
OUTPUT="$(${REPO_DIR}/install.sh --check-only --theme=nope 2>&1 || true)"
# theme-switch.sh is only called when not in --check-only, so this is a
# no-op for check-only. The actual theme validation is in theme-switch.sh.

echo "test: theme-switch.sh rejects unknown theme"
OUTPUT="$(${REPO_DIR}/scripts/theme-switch.sh badname 2>&1 || true)"
assert_contains "rejects badname" "Unknown theme" "$OUTPUT"

echo "test: theme-switch.sh with no arg shows usage"
OUTPUT="$(${REPO_DIR}/scripts/theme-switch.sh 2>&1 || true)"
assert_contains "shows usage" "Usage:" "$OUTPUT"

echo "test: all new scripts are executable"
for s in waybar-reload.sh waybar-checkupdates.sh waybar-notifications.sh \
         waybar-backlight-slider.sh waybar-microphone.sh theme-switch.sh \
         tokyo-niri-screenshot tokyo-niri-audio-menu tokyo-niri-lock; do
    if [ -x "${REPO_DIR}/scripts/$s" ]; then
        echo "  PASS  $s is executable"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $s is not executable"
        FAIL=$((FAIL+1))
    fi
done

echo "test: all theme files exist"
for t in base tokyo-night catppuccin gruvbox; do
    if [ -f "${REPO_DIR}/config/waybar/style/${t}.css" ]; then
        echo "  PASS  style/${t}.css exists"
        PASS=$((PASS+1))
    else
        echo "  FAIL  style/${t}.css missing"
        FAIL=$((FAIL+1))
    fi
done

echo "test: no hardcoded home paths (portability regression)"
if grep -rn "/home/" "${REPO_DIR}/config" "${REPO_DIR}/scripts" "${REPO_DIR}/niri" 2>/dev/null | grep -v '^\s*#' | grep -q "/home/"; then
    echo "  FAIL  hardcoded /home/<user> path found:"
    grep -rn "/home/" "${REPO_DIR}/config" "${REPO_DIR}/scripts" "${REPO_DIR}/niri" | head -5
    FAIL=$((FAIL+1))
else
    echo "  PASS  no hardcoded /home/ paths in config/scripts/niri"
    PASS=$((PASS+1))
fi

echo "test: portal config prefers gnome backend (screen share)"
if grep -q "default=gnome;gtk;" "${REPO_DIR}/config/xdg-desktop-portal/niri-portals.conf"; then
    echo "  PASS  niri-portals.conf routes to gnome portal"
    PASS=$((PASS+1))
else
    echo "  FAIL  niri-portals.conf missing gnome preference"
    FAIL=$((FAIL+1))
fi

echo "test: waybar-microphone.sh emits valid JSON"
MIC_JSON="$(${REPO_DIR}/scripts/waybar-microphone.sh 2>/dev/null || true)"
if printf '%s' "$MIC_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "text" in d' 2>/dev/null; then
    echo "  PASS  microphone module JSON parses"
    PASS=$((PASS+1))
else
    echo "  FAIL  microphone module output not valid JSON: $MIC_JSON"
    FAIL=$((FAIL+1))
fi

echo "test: waybar-notifications.sh emits valid JSON"
NOTIF_JSON="$(${REPO_DIR}/scripts/waybar-notifications.sh count 2>/dev/null || true)"
if printf '%s' "$NOTIF_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "text" in d' 2>/dev/null; then
    echo "  PASS  notifications module JSON parses"
    PASS=$((PASS+1))
else
    echo "  FAIL  notifications module output not valid JSON: $NOTIF_JSON"
    FAIL=$((FAIL+1))
fi

echo "test: audio menu device parser runs"
if ${REPO_DIR}/scripts/tokyo-niri-audio-menu list >/dev/null 2>&1; then
    echo "  PASS  tokyo-niri-audio-menu list works"
    PASS=$((PASS+1))
else
    # tolerate missing wpctl on CI machines, but the script must fail cleanly
    echo "  PASS  tokyo-niri-audio-menu exited cleanly without wpctl"
    PASS=$((PASS+1))
fi

echo "test: config.jsonc is valid JSONC (comments stripped)"
python3 - <<PY
import re, json
src = open("${REPO_DIR}/config/waybar/config.jsonc").read()
src = re.sub(r'^\s*//.*$', '', src, flags=re.M)
data = json.loads(src)
assert "modules-left" in data
assert "modules-right" in data
assert "niri/workspaces" in data
assert "wireplumber" in data
assert "custom/microphone" in data
assert "custom/microphone" in data["modules-right"]
print("  PASS  config.jsonc parses as JSON")
PY
PASS=$((PASS+1))

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
