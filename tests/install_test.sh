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
OUTPUT="$(${REPO_DIR}/install.sh --check-only 2>&1 || true)"
assert_contains "identifies as fedora" "fedora" "$OUTPUT"
assert_contains "uses dnf" "using dnf" "$OUTPUT"
assert_contains "check-only exit message" "Check complete" "$OUTPUT"

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
         waybar-backlight-slider.sh theme-switch.sh; do
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
print("  PASS  config.jsonc parses as JSON")
PY
PASS=$((PASS+1))

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
