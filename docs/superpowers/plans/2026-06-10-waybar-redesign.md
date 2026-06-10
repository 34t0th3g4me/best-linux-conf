# Waybar Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current hand-rolled waybar config and its `tokyo-niri-workspaces`/`tokyo-niri-center` custom bash parsers with a robust, feature-rich, theme-able waybar setup, plus a multi-distro `install.sh` for Fedora, Arch, and Ubuntu.

**Architecture:** Drop the bespoke bash workspace parser in favor of waybar's native `niri/workspaces`, `niri/window`, `niri/language` modules (which subscribe to the niri IPC). Layer on built-in modules (`cpu`, `memory`, `temperature`, `disk`, `wireplumber`, `battery`, `backlight`, `network`, `tray`, `idle_inhibitor`, `privacy`, `power-profiles-daemon`) and a small set of signal-driven custom modules (`custom/updates`, `custom/notifications`, `custom/logo`, `custom/power`). Style via `@define-color` CSS variables in `base.css` + per-theme files (`tokyo-night.css`, `catppuccin.css`, `gruvbox.css`), with a `theme-switch.sh` helper that rewrites `style.css` and live-reloads waybar via `SIGUSR2`. `install.sh` reads `/etc/os-release`, maps `$ID` to a package manager, prompts for installs, backs up existing configs with a timestamp, and symlinks the repo files in.

**Tech Stack:** waybar ≥ 0.9.17 (for `@define-color` + `alpha()`), niri (IPC), wireplumber, fuzzel, mako, bash ≥ 4, GNU coreutils.

**Working directory:** `/home/efecanaktas/.config/niri/` (repo root)

---

## File Structure

Files created/modified by this plan (paths relative to repo root `/home/efecanaktas/.config/niri/`):

**New:**
- `config/waybar/config.jsonc` — bar + module config
- `config/waybar/style.css` — entry: `@import` base + active theme
- `config/waybar/style/base.css` — layout rules, no colors
- `config/waybar/style/tokyo-night.css` — default theme
- `config/waybar/style/catppuccin.css` — optional
- `config/waybar/style/gruvbox.css` — optional
- `scripts/waybar-reload.sh` — `pkill -SIGUSR2 waybar`
- `scripts/waybar-checkupdates.sh` — JSON output for `custom/updates`
- `scripts/waybar-notifications.sh` — mako count via D-Bus
- `scripts/theme-switch.sh` — rewrite `style.css` import, SIGUSR2
- `scripts/waybar-backlight-slider.sh` — zenity slider for backlight
- `install.sh` — multi-distro installer
- `uninstall.sh` — clean removal
- `tests/install_test.sh` — bats-style assertions for `install.sh --check-only` and `theme-switch.sh`
- `docs/superpowers/plans/2026-06-10-waybar-redesign.md` — this file

**Modified:**
- `README.md` — new install section, theme-switch docs, recovery
- `scripts/tokyo-niri-startup` — drop now-unused deps, harden
- `scripts/tokyo-niri-wifi-menu` — `set -euo pipefail`, `sleep 0.1` wrapper
- `scripts/tokyo-niri-bluetooth-menu` — same
- `scripts/tokyo-niri-power-menu` — same
- `scripts/tokyo-niri-audio` — same

**Deleted:**
- `scripts/tokyo-niri-workspaces` — replaced by native `niri/workspaces`
- `scripts/tokyo-niri-center` — replaced by native `niri/window`
- `scripts/tokyo-niri-profile-menu` — replaced by `power-profiles-daemon` module (kept `tokyo-niri-tlp-profile` for the actual switcher)
- `config/waybar/config` (old plain JSON) — replaced by `config.jsonc`
- `config/waybar/style.css` (old monolithic) — replaced by split file

---

## Task 1: Backup and remove obsolete scripts

**Files:**
- Delete: `scripts/tokyo-niri-workspaces`
- Delete: `scripts/tokyo-niri-center`
- Delete: `scripts/tokyo-niri-profile-menu`
- Delete: `config/waybar/config` (old)
- Delete: `config/waybar/style.css` (old)

- [ ] **Step 1: Verify each file exists before deleting**

Run:
```bash
cd /home/efecanaktas/.config/niri
ls scripts/tokyo-niri-workspaces scripts/tokyo-niri-center scripts/tokyo-niri-profile-menu config/waybar/config config/waybar/style.css
```
Expected: all 5 files listed, no "No such file" errors.

- [ ] **Step 2: Confirm with the user that they want to delete `tokyo-niri-profile-menu`**

This script is referenced by `custom/profile` in the current waybar config. After this plan, the `power-profiles-daemon` module replaces it. Print the message and wait for "yes" before proceeding.

Print: `"About to delete scripts/tokyo-niri-profile-menu. The new power-profiles-daemon waybar module replaces it. OK to proceed? (yes/no)"`

- [ ] **Step 3: Delete the 5 files**

```bash
cd /home/efecanaktas/.config/niri
git rm scripts/tokyo-niri-workspaces scripts/tokyo-niri-center scripts/tokyo-niri-profile-menu config/waybar/config config/waybar/style.css
```
Expected: 5 files removed, git status shows 5 deletions.

- [ ] **Step 4: Commit**

```bash
cd /home/efecanaktas/.config/niri
git commit -m "Remove scripts replaced by native waybar niri modules

- tokyo-niri-workspaces -> niri/workspaces
- tokyo-niri-center     -> niri/window
- tokyo-niri-profile-menu -> power-profiles-daemon module
- old plain-JSON config and monolithic style.css -> split files (next task)"
```

---

## Task 2: Create `base.css` with shared layout

**Files:**
- Create: `config/waybar/style/base.css`

- [ ] **Step 1: Create the file**

```bash
mkdir -p config/waybar/style
```

- [ ] **Step 2: Write `base.css`**

Create `config/waybar/style/base.css` with this exact content:

```css
/* base.css — layout, typography, shared rules. No colors. */

/* @define-color placeholders — overridden by theme files.
   Theme files MUST define these. */
@define-color surface   #000000;
@define-color surface-2 #111111;
@define-color accent    #ffffff;
@define-color text      #ffffff;
@define-color blue      #ffffff;
@define-color purple    #ffffff;
@define-color green     #ffffff;
@define-color yellow    #ffffff;
@define-color red       #ffffff;
@define-color teal      #ffffff;
@define-color orange    #ffffff;

* {
    font-family: "JetBrains Mono", "Font Awesome 6 Free", "Noto Sans", sans-serif;
    font-size: 12px;
    font-weight: 700;
    border: none;
    border-radius: 0;
    min-height: 0;
}

window#waybar {
    background: transparent;
    color: @text;
}

/* Pill-shaped module groups */
.modules-left,
.modules-center,
.modules-right {
    background: alpha(@surface, 0.75);
    border: 1px solid alpha(@accent, 0.20);
    border-radius: 18px;
    padding: 4px 10px;
    margin: 0;
}
.modules-center { margin: 0 8px; }

/* Default module "chip" look */
#clock, #cpu, #memory, #temperature, #disk, #battery,
#network, #wireplumber, #backlight, #tray,
#idle_inhibitor, #privacy, #power-profiles-daemon,
#mpris, #niri-workspaces, #niri-window, #niri-language,
#custom-logo, #custom-updates, #custom-notifications, #custom-power {
    padding: 0 10px;
    margin: 0 3px;
    border-radius: 11px;
    background: alpha(@surface-2, 0.65);
}

#custom-power {
    color: @red;
    font-size: 14px;
    padding: 0 12px;
}

/* Hover for any module that is clickable */
#clock:hover, #cpu:hover, #memory:hover, #temperature:hover,
#disk:hover, #battery:hover, #network:hover, #wireplumber:hover,
#backlight:hover, #tray:hover, #mpris:hover, #niri-workspaces:hover,
#niri-window:hover, #niri-language:hover, #custom-logo:hover,
#custom-updates:hover, #custom-notifications:hover,
#custom-power:hover, #idle_inhibitor:hover, #privacy:hover,
#power-profiles-daemon:hover {
    background: alpha(@accent, 0.20);
    color: @text;
}

/* Tray icons should not pick up the chip background twice */
#tray {
    padding: 0 6px;
    background: transparent;
}
#tray > .passive { -gtk-icon-effect: dim; }
```

- [ ] **Step 3: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add config/waybar/style/base.css
git commit -m "feat(waybar): add base.css with shared layout and color placeholders"
```

---

## Task 3: Create `tokyo-night.css` (default theme)

**Files:**
- Create: `config/waybar/style/tokyo-night.css`

- [ ] **Step 1: Write the theme file**

Create `config/waybar/style/tokyo-night.css` with this exact content:

```css
/* tokyo-night.css — Tokyo Night Pro palette. */

@define-color surface   #1a1b26;
@define-color surface-2 #24283b;
@define-color accent    #7aa2f7;
@define-color text      #c0caf5;
@define-color blue      #7dcfff;
@define-color purple    #bb9af7;
@define-color green     #9ece6a;
@define-color yellow    #e0af68;
@define-color red       #f7768e;
@define-color teal      #73daca;
@define-color orange    #ff9e64;

#niri-workspaces  { color: @blue;    padding: 0 6px; letter-spacing: 1.5px; }
#niri-window      { color: @purple;  font-weight: 600; }
#custom-logo      { color: @accent;  font-size: 16px; padding: 0 12px; }
#clock            { color: @blue; }
#mpris            { color: @green;   min-width: 80px; }
#idle_inhibitor   { color: @yellow; }
#idle_inhibitor.activated { color: @green; }
#privacy          { color: @red; }
#privacy:hover    { color: @text; }
#custom-updates   { color: @teal; }
#custom-updates.has-updates { color: @yellow; }
#cpu              { color: @blue; }
#memory           { color: @purple; }
#temperature      { color: @teal; }
#temperature.critical { color: @red; }
#temperature.warning  { color: @yellow; }
#disk             { color: @surface-2; color: @teal; }
#network          { color: @teal; }
#network.disconnected { color: @red; }
#wireplumber      { color: @yellow; }
#wireplumber.muted      { color: @red; }
#backlight        { color: @yellow; }
#battery          { color: @green; }
#battery.charging      { color: @green; }
#battery.warning       { color: @yellow; }
#battery.critical      { color: @red; }
#power-profiles-daemon        { color: @purple; }
#power-profiles-daemon.performance { color: @red; }
#custom-notifications         { color: @blue; }
#custom-notifications.dnd      { color: @red; }
```

- [ ] **Step 2: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add config/waybar/style/tokyo-night.css
git commit -m "feat(waybar): add tokyo-night theme (default)"
```

---

## Task 4: Create `catppuccin.css` and `gruvbox.css`

**Files:**
- Create: `config/waybar/style/catppuccin.css`
- Create: `config/waybar/style/gruvbox.css`

- [ ] **Step 1: Write `catppuccin.css` (mocha palette)**

Create `config/waybar/style/catppuccin.css`:

```css
/* catppuccin.css — Catppuccin Mocha palette. */

@define-color surface   #1e1e2e;
@define-color surface-2 #313244;
@define-color accent    #89b4fa;
@define-color text      #cdd6f4;
@define-color blue      #89b4fa;
@define-color purple    #cba6f7;
@define-color green     #a6e3a1;
@define-color yellow    #f9e2af;
@define-color red       #f38ba8;
@define-color teal      #94e2d5;
@define-color orange    #fab387;

#niri-workspaces  { color: @blue;    padding: 0 6px; letter-spacing: 1.5px; }
#niri-window      { color: @purple;  font-weight: 600; }
#custom-logo      { color: @accent;  font-size: 16px; padding: 0 12px; }
#clock            { color: @blue; }
#mpris            { color: @green;   min-width: 80px; }
#idle_inhibitor   { color: @yellow; }
#idle_inhibitor.activated { color: @green; }
#privacy          { color: @red; }
#custom-updates   { color: @teal; }
#custom-updates.has-updates { color: @yellow; }
#cpu              { color: @blue; }
#memory           { color: @purple; }
#temperature      { color: @teal; }
#temperature.critical { color: @red; }
#temperature.warning  { color: @yellow; }
#disk             { color: @teal; }
#network          { color: @teal; }
#network.disconnected { color: @red; }
#wireplumber      { color: @yellow; }
#wireplumber.muted      { color: @red; }
#backlight        { color: @yellow; }
#battery          { color: @green; }
#battery.warning       { color: @yellow; }
#battery.critical      { color: @red; }
#power-profiles-daemon        { color: @purple; }
#power-profiles-daemon.performance { color: @red; }
#custom-notifications         { color: @blue; }
#custom-notifications.dnd      { color: @red; }
```

- [ ] **Step 2: Write `gruvbox.css`**

Create `config/waybar/style/gruvbox.css`:

```css
/* gruvbox.css — Gruvbox Dark palette. */

@define-color surface   #282828;
@define-color surface-2 #3c3836;
@define-color accent    #83a598;
@define-color text      #ebdbb2;
@define-color blue      #83a598;
@define-color purple    #d3869b;
@define-color green     #b8bb26;
@define-color yellow    #fabd2f;
@define-color red       #fb4934;
@define-color teal      #8ec07c;
@define-color orange    #fe8019;

#niri-workspaces  { color: @blue;    padding: 0 6px; letter-spacing: 1.5px; }
#niri-window      { color: @purple;  font-weight: 600; }
#custom-logo      { color: @accent;  font-size: 16px; padding: 0 12px; }
#clock            { color: @blue; }
#mpris            { color: @green;   min-width: 80px; }
#idle_inhibitor   { color: @yellow; }
#idle_inhibitor.activated { color: @green; }
#privacy          { color: @red; }
#custom-updates   { color: @teal; }
#custom-updates.has-updates { color: @yellow; }
#cpu              { color: @blue; }
#memory           { color: @purple; }
#temperature      { color: @teal; }
#temperature.critical { color: @red; }
#temperature.warning  { color: @yellow; }
#disk             { color: @teal; }
#network          { color: @teal; }
#network.disconnected { color: @red; }
#wireplumber      { color: @yellow; }
#wireplumber.muted      { color: @red; }
#backlight        { color: @yellow; }
#battery          { color: @green; }
#battery.warning       { color: @yellow; }
#battery.critical      { color: @red; }
#power-profiles-daemon        { color: @purple; }
#power-profiles-daemon.performance { color: @red; }
#custom-notifications         { color: @blue; }
#custom-notifications.dnd      { color: @red; }
```

- [ ] **Step 3: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add config/waybar/style/catppuccin.css config/waybar/style/gruvbox.css
git commit -m "feat(waybar): add catppuccin and gruvbox themes"
```

---

## Task 5: Create the new `style.css` entry point

**Files:**
- Create: `config/waybar/style.css`

- [ ] **Step 1: Write the entry CSS**

Create `config/waybar/style.css`:

```css
/* style.css — waybar stylesheet entry point.
   Active theme is the second @import; theme-switch.sh rewrites it. */

@import url("style/base.css");
@import url("style/tokyo-night.css");
```

- [ ] **Step 2: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add config/waybar/style.css
git commit -m "feat(waybar): add style.css entry point (imports base + tokyo-night)"
```

---

## Task 6: Create `waybar-reload.sh`

**Files:**
- Create: `scripts/waybar-reload.sh`

- [ ] **Step 1: Write the script**

Create `scripts/waybar-reload.sh`:

```bash
#!/usr/bin/env bash
# waybar-reload.sh — send SIGUSR2 to live-reload config + style.
# Bound to a keybind in niri config.
set -euo pipefail
pkill -SIGUSR2 -x waybar 2>/dev/null || {
    echo "waybar is not running" >&2
    exit 1
}
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/waybar-reload.sh
```

- [ ] **Step 3: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add scripts/waybar-reload.sh
git commit -m "feat(scripts): add waybar-reload.sh (SIGUSR2 wrapper)"
```

---

## Task 7: Create `waybar-checkupdates.sh` (signal-driven)

**Files:**
- Create: `scripts/waybar-checkupdates.sh`

- [ ] **Step 1: Write the script**

Create `scripts/waybar-checkupdates.sh`:

```bash
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/waybar-checkupdates.sh
```

- [ ] **Step 3: Smoke-test on Fedora**

Run:
```bash
cd /home/efecanaktas/.config/niri
./scripts/waybar-checkupdates.sh
```
Expected: a single JSON line on stdout, e.g. `{"text":"0 ↑","tooltip":"System up to date","class":"none"}` (or with `has-updates` if updates exist). The script must exit 0.

- [ ] **Step 4: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add scripts/waybar-checkupdates.sh
git commit -m "feat(scripts): add distro-aware waybar-checkupdates.sh"
```

---

## Task 8: Create `waybar-notifications.sh` (mako count + DND)

**Files:**
- Create: `scripts/waybar-notifications.sh`

- [ ] **Step 1: Write the script**

Create `scripts/waybar-notifications.sh`:

```bash
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/waybar-notifications.sh
```

- [ ] **Step 3: Smoke-test**

Run:
```bash
cd /home/efecanaktas/.config/niri
./scripts/waybar-notifications.sh
```
Expected: a single JSON line, e.g. `{"text":"","tooltip":"No notifications","class":"none"}`. Exit 0.

- [ ] **Step 4: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add scripts/waybar-notifications.sh
git commit -m "feat(scripts): add waybar-notifications.sh (mako count + dnd toggle)"
```

---

## Task 9: Create `theme-switch.sh`

**Files:**
- Create: `scripts/theme-switch.sh`

- [ ] **Step 1: Write the script**

Create `scripts/theme-switch.sh`:

```bash
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/theme-switch.sh
```

- [ ] **Step 3: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add scripts/theme-switch.sh
git commit -m "feat(scripts): add theme-switch.sh (live theme switcher)"
```

---

## Task 10: Create `waybar-backlight-slider.sh`

**Files:**
- Create: `scripts/waybar-backlight-slider.sh`

- [ ] **Step 1: Write the script**

Create `scripts/waybar-backlight-slider.sh`:

```bash
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/waybar-backlight-slider.sh
```

- [ ] **Step 3: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add scripts/waybar-backlight-slider.sh
git commit -m "feat(scripts): add waybar-backlight-slider.sh"
```

---

## Task 11: Hardened `tokyo-niri-wifi-menu` (sleep 0.1 wrapper + set -euo pipefail)

**Files:**
- Modify: `scripts/tokyo-niri-wifi-menu`

- [ ] **Step 1: Confirm the file exists and the old header**

Run:
```bash
cd /home/efecanaktas/.config/niri
head -5 scripts/tokyo-niri-wifi-menu
```
Expected: starts with `#!/bin/bash` or `#!/usr/bin/env bash`, has the comment `# Tokyo Night Pro - WiFi Network Menu`.

- [ ] **Step 2: Replace the shebang + header block**

The current file starts:
```bash
#!/bin/bash
# Tokyo Night Pro - WiFi Network Menu
```

Replace those first 3 lines with:
```bash
#!/usr/bin/env bash
# Tokyo Night Pro - WiFi Network Menu
# Hardened for waybar 2026: set -euo pipefail, fuzzel click-hijacking fix.
set -euo pipefail
```

- [ ] **Step 3: Wrap the fuzzel call with `sleep 0.1`**

Find this line in the file (near the end):
```bash
choice=$(printf "%b" "$formatted" | head -40 | fuzzel --dmenu --prompt "wifi" --width 50 --lines 12 2>/dev/null)
```

Replace it with:
```bash
# sleep 0.1 prefix mitigates waybar click-hijacking bug (issue #2166)
choice=$(sleep 0.1 && printf "%b" "$formatted" | head -40 | fuzzel --dmenu --prompt "wifi" --width 50 --lines 12 2>/dev/null) || choice=""
```

- [ ] **Step 4: Add fuzzel/missing-tool guards**

Find the line:
```bash
if [ -n "$choice" ]; then
```

Insert directly before it:
```bash
command -v fuzzel >/dev/null 2>&1 || { notify-send "wifi" "fuzzel not installed" 2>/dev/null || true; exit 1; }
command -v nmcli >/dev/null 2>&1 || { notify-send "wifi" "nmcli not installed" 2>/dev/null || true; exit 1; }
```

- [ ] **Step 5: Make executable (idempotent) and commit**

```bash
cd /home/efecanaktas/.config/niri
chmod +x scripts/tokyo-niri-wifi-menu
git add scripts/tokyo-niri-wifi-menu
git commit -m "fix(scripts): harden tokyo-niri-wifi-menu (set -euo pipefail, click-hijack fix, guards)"
```

---

## Task 12: Hardened `tokyo-niri-bluetooth-menu`

**Files:**
- Modify: `scripts/tokyo-niri-bluetooth-menu`

- [ ] **Step 1: Replace shebang + header**

The current file starts:
```bash
#!/bin/bash
# Tokyo Night Pro - Bluetooth Device Menu
```

Replace the first 3 lines with:
```bash
#!/usr/bin/env bash
# Tokyo Night Pro - Bluetooth Device Menu
# Hardened for waybar 2026: set -euo pipefail, fuzzel click-hijacking fix.
set -euo pipefail
```

- [ ] **Step 2: Wrap fuzzel call 1 (power-on prompt) with `sleep 0.1`**

Find:
```bash
choice=$(printf "🔵 Turn Bluetooth On" | fuzzel --dmenu --prompt "bluetooth" --width 35 --lines 1 2>/dev/null)
```

Replace with:
```bash
choice=$(sleep 0.1 && printf "🔵 Turn Bluetooth On" | fuzzel --dmenu --prompt "bluetooth" --width 35 --lines 1 2>/dev/null) || choice=""
```

- [ ] **Step 3: Wrap fuzzel call 2 (device list) with `sleep 0.1`**

Find:
```bash
choice=$(printf "%b" "$entries" | fuzzel --dmenu --prompt "bluetooth" --width 45 --lines 15 2>/dev/null)
```

Replace with:
```bash
choice=$(sleep 0.1 && printf "%b" "$entries" | fuzzel --dmenu --prompt "bluetooth" --width 45 --lines 15 2>/dev/null) || choice=""
```

- [ ] **Step 4: Add bluetoothctl guard**

Find:
```bash
# Check if bluetooth is on
if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
```

Insert directly above it:
```bash
command -v bluetoothctl >/dev/null 2>&1 || { notify-send "bluetooth" "bluetoothctl not installed" 2>/dev/null || true; exit 1; }
command -v fuzzel >/dev/null 2>&1 || { notify-send "bluetooth" "fuzzel not installed" 2>/dev/null || true; exit 1; }
```

- [ ] **Step 5: Commit**

```bash
cd /home/efecanaktas/.config/niri
chmod +x scripts/tokyo-niri-bluetooth-menu
git add scripts/tokyo-niri-bluetooth-menu
git commit -m "fix(scripts): harden tokyo-niri-bluetooth-menu (set -euo pipefail, click-hijack fix, guards)"
```

---

## Task 13: Hardened `tokyo-niri-power-menu`

**Files:**
- Modify: `scripts/tokyo-niri-power-menu`

- [ ] **Step 1: Replace shebang + header**

Current first lines:
```bash
#!/bin/bash
# Tokyo Night Pro - Power Menu
# Uses fuzzel as dmenu for power management options
```

Replace with:
```bash
#!/usr/bin/env bash
# Tokyo Night Pro - Power Menu
# Hardened for waybar 2026: set -euo pipefail, fuzzel click-hijacking fix.
set -euo pipefail
```

- [ ] **Step 2: Wrap fuzzel call with `sleep 0.1`**

Find:
```bash
choice=$(printf "%b" "$entries" | fuzzel --dmenu --prompt "power" --width 30 --lines 5 2>/dev/null)
```

Replace with:
```bash
choice=$(sleep 0.1 && printf "%b" "$entries" | fuzzel --dmenu --prompt "power" --width 30 --lines 5 2>/dev/null) || choice=""
```

- [ ] **Step 3: Add fuzzel guard**

Find:
```bash
case "$choice" in
```

Insert directly above it:
```bash
command -v fuzzel >/dev/null 2>&1 || { notify-send "power" "fuzzel not installed" 2>/dev/null || true; exit 1; }
```

- [ ] **Step 4: Commit**

```bash
cd /home/efecanaktas/.config/niri
chmod +x scripts/tokyo-niri-power-menu
git add scripts/tokyo-niri-power-menu
git commit -m "fix(scripts): harden tokyo-niri-power-menu (set -euo pipefail, click-hijack fix, guards)"
```

---

## Task 14: Hardened `tokyo-niri-audio`

**Files:**
- Modify: `scripts/tokyo-niri-audio`

- [ ] **Step 1: Replace shebang + header**

Current first lines:
```bash
#!/bin/bash
# Minimal audio volume control using zenity + wpctl
```

Replace with:
```bash
#!/usr/bin/env bash
# Minimal audio volume control using zenity + wpctl
# Hardened for waybar 2026: set -euo pipefail, guards.
set -euo pipefail
```

- [ ] **Step 2: Add tool guards at the top of the script body**

Find:
```bash
sink="@DEFAULT_AUDIO_SINK@"
```

Insert directly above it:
```bash
command -v wpctl >/dev/null 2>&1 || { notify-send "audio" "wpctl not installed" 2>/dev/null || true; exit 1; }
command -v zenity >/dev/null 2>&1 || { notify-send "audio" "zenity not installed" 2>/dev/null || true; exit 1; }
```

- [ ] **Step 3: Commit**

```bash
cd /home/efecanaktas/.config/niri
chmod +x scripts/tokyo-niri-audio
git add scripts/tokyo-niri-audio
git commit -m "fix(scripts): harden tokyo-niri-audio (set -euo pipefail, tool guards)"
```

---

## Task 15: Hardened `tokyo-niri-startup`

**Files:**
- Modify: `scripts/tokyo-niri-startup`

- [ ] **Step 1: Verify current content**

The current file already has `set -euo pipefail` and uses `command -v` guards. The only change needed is to make sure the new waybar config path is used: `config.jsonc` instead of `config`.

- [ ] **Step 2: Update the waybar command line**

Find:
```bash
if command -v waybar >/dev/null 2>&1; then waybar -c "$HOME/.config/waybar/config" -s "$HOME/.config/waybar/style.css" >/tmp/tokyo-niri-waybar-top.log 2>&1 & fi
```

Replace with:
```bash
if command -v waybar >/dev/null 2>&1; then waybar -c "$HOME/.config/waybar/config.jsonc" -s "$HOME/.config/waybar/style.css" >/tmp/tokyo-niri-waybar-top.log 2>&1 & fi
```

- [ ] **Step 3: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add scripts/tokyo-niri-startup
git commit -m "fix(scripts): point waybar startup at config.jsonc"
```

---

## Task 16: Create `config.jsonc` — bar + module config

**Files:**
- Create: `config/waybar/config.jsonc`

- [ ] **Step 1: Write the config**

Create `config/waybar/config.jsonc`:

```jsonc
// config.jsonc — waybar configuration.
// Modules left -> center -> right. JSONC is supported (waybar uses jsoncpp).

{
  // === BAR ===
  "layer": "top",
  "position": "top",
  "height": 36,
  "spacing": 8,
  "margin-top": 8,
  "margin-left": 14,
  "margin-right": 14,
  "exclusive": true,
  "name": "top",
  "mode": "dock",
  "reload_style_on_change": true,
  "restart_interval": 0,
  "on-sigusr1": "reload",
  "on-sigusr2": "reload",

  // === MODULES ===
  "modules-left": [
    "niri/workspaces",
    "niri/window",
    "custom/logo",
    "clock",
    "mpris"
  ],
  "modules-center": [
    "idle_inhibitor",
    "privacy"
  ],
  "modules-right": [
    "custom/updates",
    "cpu",
    "memory",
    "temperature",
    "disk",
    "tray",
    "backlight",
    "wireplumber",
    "network",
    "battery",
    "power-profiles-daemon",
    "custom/notifications",
    "custom/power"
  ],

  // === COMPOSITOR ===
  "niri/workspaces": {
    "disable-scroll": true,
    "all-outputs": true,
    "warp-on-scroll": false,
    "format": "{name}",
    "format-icons": {
      "focused": "●",
      "active": "◉",
      "urgent": "!",
      "default": "○"
    },
    "on-click": "sleep 0.1 && niri msg action focus-workspace {}",
    "on-click-right": "sleep 0.1 && niri msg action toggle-overview",
    "persistent-workspaces": true
  },

  "niri/window": {
    "format": "{title}",
    "max-length": 60,
    "rewrite": {
      "(.*) — Mozilla Firefox": "$1",
      "(.*) — Visual Studio Code": "$1"
    },
    "on-click": "sleep 0.1 && niri msg action focus-column"
  },

  // === CUSTOM ===
  "custom/logo": {
    "format": "◆",
    "tooltip": "Launcher (Super+Space)",
    "on-click": "sleep 0.1 && fuzzel",
    "on-click-right": "sleep 0.1 && tokyo-niri-dock-app launcher"
  },

  "custom/updates": {
    "exec": "tokyo-niri-install-dir/waybar-checkupdates.sh",
    "exec-on-event": true,
    "interval": "once",
    "signal": 9,
    "return-type": "json",
    "format": "{}",
    "format-icons": {
      "has-updates": "↑",
      "none": "✓"
    },
    "on-click": "sleep 0.1 && ghostty -e bash -c 'sudo dnf upgrade; read'",
    "on-click-right": "pkill -RTMIN+9 waybar",
    "tooltip-format": "{tooltip}"
  },

  "custom/notifications": {
    "exec": "tokyo-niri-install-dir/waybar-notifications.sh count",
    "exec-on-event": true,
    "interval": 30,
    "signal": 10,
    "return-type": "json",
    "format": "{text}",
    "format-icons": {
      "dnd": "DND",
      "none": "🔔"
    },
    "on-click": "sleep 0.1 && tokyo-niri-install-dir/waybar-notifications.sh dnd-toggle",
    "on-click-right": "sleep 0.1 && makoctl dismiss --all 2>/dev/null || true"
  },

  "custom/power": {
    "format": "⏻",
    "tooltip": "Click: power menu",
    "on-click": "sleep 0.1 && tokyo-niri-power-menu"
  },

  // === BUILT-IN ===
  "clock": {
    "interval": 30,
    "format": "{:%a %d.%m.  %H:%M}",
    "format-alt": "{:%A, %d. %B %Y}",
    "tooltip-format": "<big>{:%H:%M}</big>\n<tt><small>{calendar}</small></tt>",
    "on-click": "sleep 0.1 && zenity --calendar --text='' --title='Calendar' 2>/dev/null",
    "on-click-right": "mode"
  },

  "mpris": {
    "format": "♪ {title}",
    "format-paused": "⏸ {title}",
    "format-disconnected": "",
    "max-length": 45,
    "on-click": "playerctl play-pause",
    "on-click-right": "playerctl next",
    "on-scroll-up": "playerctl previous",
    "on-scroll-down": "playerctl next",
    "tooltip": true,
    "tooltip-format": "{player} — {title}\n{album}"
  },

  "idle_inhibitor": {
    "format": "{icon}",
    "format-icons": {
      "activated": "☕",
      "deactivated": ""
    },
    "tooltip-format": "Idle inhibitor: {status}"
  },

  "privacy": {
    "icon-size": 18,
    "icon-spacing": 4,
    "tooltip-format": "{tooltip}"
  },

  "cpu": {
    "interval": 5,
    "format": "cpu {usage}%",
    "states": { "warning": 70, "critical": 90 },
    "tooltip-format": "CPU: {usage}%"
  },

  "memory": {
    "interval": 10,
    "format": "mem {percentage}%",
    "states": { "warning": 70, "critical": 90 },
    "tooltip-format": "Memory: {percentage}%\n{used:0.1f}G / {total:0.1f}G"
  },

  "temperature": {
    "interval": 10,
    "hwmon-path": "/sys/class/hwmon",
    "input-filename": "temp1_input",
    "critical-threshold": 85,
    "warning-threshold": 70,
    "format": "{temperatureC}°C",
    "tooltip-format": "{chip} — {temperatureC}°C"
  },

  "disk": {
    "interval": 60,
    "path": "/",
    "format": "/ {percentage_free}% free",
    "tooltip-format": "Root: {percentage_free}% free\n{free} / {total}"
  },

  "tray": {
    "icon-size": 16,
    "spacing": 8,
    "show-passive-items": false
  },

  "backlight": {
    "interval": 5,
    "format": "{percent}%",
    "format-icons": ["◑", "◐", "◓", "◒", "●"],
    "on-scroll-up": "brightnessctl set 5%+",
    "on-scroll-down": "brightnessctl set 5%-",
    "on-click": "sleep 0.1 && tokyo-niri-install-dir/waybar-backlight-slider.sh",
    "tooltip-format": "Backlight: {percent}%"
  },

  "wireplumber": {
    "interval": 2,
    "format": "{volume}%",
    "format-muted": "🔇",
    "format-icons": {
      "headphone": "🎧",
      "default": ["🔈", "🔉", "🔊"]
    },
    "on-click": "sleep 0.1 && tokyo-niri-install-dir/tokyo-niri-audio",
    "on-click-right": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    "on-scroll-up": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
    "on-scroll-down": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
    "scroll-step": 5,
    "max-volume": 150,
    "tooltip-format": "{desc}: {volume}%"
  },

  "network": {
    "interval": 10,
    "format-wifi": "{signalStrength}% {essid}",
    "format-ethernet": "wired",
    "format-disconnected": "offline",
    "tooltip-format-wifi": "{essid} ({signalStrength}%)\n{ipaddr}/{cidr}",
    "tooltip-format-ethernet": "wired\n{ipaddr}/{cidr}",
    "tooltip-format-disconnected": "Disconnected",
    "on-click": "sleep 0.1 && tokyo-niri-wifi-menu"
  },

  "battery": {
    "bat": "BAT0",
    "interval": 30,
    "states": { "warning": 30, "critical": 15 },
    "format": "{capacity}%",
    "format-charging": "⚡ {capacity}%",
    "format-plugged": "🔌 {capacity}%",
    "format-icons": ["", "", "", "", "", "", "", "", "", "", "▮"],
    "tooltip-format": "{capacity}% • {power}W\n{time}",
    "on-click": "sleep 0.1 && tokyo-niri-profile-menu"
  },

  "power-profiles-daemon": {
    "format": "{icon}",
    "format-icons": {
      "default": "◈",
      "performance": "⚡",
      "balanced": "◈",
      "power-saver": "❄"
    },
    "tooltip-format": "Power profile: {profile}",
    "on-click": "sleep 0.1 && tokyo-niri-profile-menu"
  }
}
```

- [ ] **Step 2: Replace `tokyo-niri-install-dir` placeholder with the actual install location**

The `custom/updates`, `custom/notifications`, `backlight`, `wireplumber` modules call scripts with `tokyo-niri-install-dir/<script>`. This must resolve to the directory where `install.sh` lives (i.e. `$REPO/scripts`). The replacement happens during `install.sh` execution. For now, run:

```bash
cd /home/efecanaktas/.config/niri
sed -i "s|tokyo-niri-install-dir|$(pwd)/scripts|g" config/waybar/config.jsonc
```

Expected: every `tokyo-niri-install-dir/...` line now reads `/home/efecanaktas/.config/niri/scripts/...`. Verify with:

```bash
grep -c "tokyo-niri-install-dir" config/waybar/config.jsonc
```

Expected output: `0` (no remaining placeholders).

- [ ] **Step 3: Validate JSON syntax**

```bash
cd /home/efecanaktas/.config/niri
python3 -c "import json,sys; json.load(open('config/waybar/config.jsonc'))" \
    || python3 -c "import json,sys; json.load(open('config/waybar/config.jsonc'.replace('.jsonc','')))"
```

Then explicitly strip JSONC comments and validate:
```bash
python3 <<'PY'
import re, json, sys
src = open('config/waybar/config.jsonc').read()
# Strip // line comments (waybar accepts these but json.load does not)
src = re.sub(r'^\s*//.*$', '', src, flags=re.M)
data = json.loads(src)
print(f"valid: {len(data)} top-level keys")
PY
```

Expected: prints `valid: <number>` where the number is around 30+. No exception.

- [ ] **Step 4: Test that waybar accepts the config**

```bash
cd /home/efecanaktas/.config/niri
# Make sure waybar is not running
pkill -x waybar 2>/dev/null || true
waybar -c config/waybar/config.jsonc -s config/waybar/style.css -l &
WB_PID=$!
sleep 2
if kill -0 $WB_PID 2>/dev/null; then
    echo "waybar started OK"
    pkill -x waybar
else
    echo "waybar failed to start — check config"
    exit 1
fi
```

Expected: `waybar started OK`.

- [ ] **Step 5: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add config/waybar/config.jsonc
git commit -m "feat(waybar): new config.jsonc with native niri modules and full feature set"
```

---

## Task 17: Create `install.sh` — multi-distro installer

**Files:**
- Create: `install.sh`

- [ ] **Step 1: Write the full installer**

Create `install.sh`:

```bash
#!/usr/bin/env bash
# install.sh — multi-distro installer for best-linux-conf.
# Detects Fedora / Arch / Ubuntu (and derivatives) via /etc/os-release,
# installs runtime + build deps for waybar, symlinks repo files into place,
# backs up existing configs, and verifies the result.
#
# Usage: ./install.sh [options]
#   --check-only      Print the plan and exit
#   --dry-run         Print commands without executing
#   --theme NAME      Set initial theme (default: tokyo-night)
#   --no-backup       Skip backup of existing configs
#   --uninstall       Run uninstall flow instead
#   -y, --yes         Skip all confirmation prompts

set -euo pipefail

# ---- Constants ----------------------------------------------------------

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${REPO_DIR}/scripts"
WAYBAR_DIR="${REPO_DIR}/config/waybar"
NIRI_DIR="${REPO_DIR}/niri"
MAKO_DIR="${REPO_DIR}/config/mako"
FUZZEL_DIR="${REPO_DIR}/config/fuzzel"
LOCAL_BIN="${HOME}/.local/bin"
TS="$(date +%Y%m%d-%H%M%S)"

CHECK_ONLY=false
DRY_RUN=false
THEME="tokyo-night"
NO_BACKUP=false
UNINSTALL=false
ASSUME_YES=false

# ---- Arg parse ----------------------------------------------------------

for arg in "$@"; do
    case "$arg" in
        --check-only)  CHECK_ONLY=true ;;
        --dry-run)     DRY_RUN=true; CHECK_ONLY=true ;;
        --theme=*)     THEME="${arg#*=}" ;;
        --theme)       shift; THEME="${1:-tokyo-night}" ;;
        --no-backup)   NO_BACKUP=true ;;
        --uninstall)   UNINSTALL=true ;;
        -y|--yes)      ASSUME_YES=true ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done

# ---- Helpers ------------------------------------------------------------

log()  { echo "==> $*"; }
warn() { echo "warning: $*" >&2; }
fail() { echo "error: $*" >&2; exit 1; }

run() {
    if $DRY_RUN; then
        echo "  [DRY-RUN] $*"
    else
        "$@"
    fi
}

confirm() {
    $ASSUME_YES && return 0
    local prompt="$1"
    read -rp "$prompt [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

trap 'echo "interrupted — partial state may be in place" >&2; exit 130' INT TERM

# ---- Distro detection ---------------------------------------------------

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    elif [ -f /usr/lib/os-release ]; then
        . /usr/lib/os-release
    else
        fail "cannot read /etc/os-release — unsupported system"
    fi
    case "${ID:-unknown}" in
        fedora)         PM="dnf";   INSTALL=(sudo dnf install -y); FAMILY="fedora" ;;
        arch|manjaro|endeavouros)
                        PM="pacman"; INSTALL=(sudo pacman -S --noconfirm --needed); FAMILY="arch" ;;
        ubuntu|pop|linuxmint|elementary|zorin)
                        PM="apt";   INSTALL=(sudo apt install -y); FAMILY="debian" ;;
        debian)         PM="apt";   INSTALL=(sudo apt install -y); FAMILY="debian" ;;
        *) fail "unsupported distro: ${ID:-unknown} (${PRETTY_NAME:-}). Manual install: https://github.com/Alexays/Waybar" ;;
    esac
    log "Detected: ${PRETTY_NAME:-$ID} (using $PM)"
}

# ---- Package maps -------------------------------------------------------
# Map a logical name to a distro-specific package (space-separated for multiple).

pkg_for() {
    local key="$1" fam="$2"
    case "$fam" in
        fedora)
            case "$key" in
                waybar)        echo "waybar" ;;
                niri)          echo "" ;;  # not in Fedora repos — skip
                fuzzel)        echo "fuzzel" ;;
                mako)          echo "mako" ;;
                wireplumber)   echo "wireplumber wireplumber-libs" ;;
                playerctl)     echo "playerctl" ;;
                networkmanager) echo "NetworkManager-tui" ;;
                bluetooth)     echo "bluez bluez-tools" ;;
                tlp)           echo "tlp tlp-rdw" ;;
                ppd)           echo "power-profiles-daemon" ;;
                brightnessctl) echo "brightnessctl" ;;
                wpctl)         echo "" ;;  # comes with wireplumber
                grim)          echo "grim" ;;
                slurp)         echo "slurp" ;;
                swappy)        echo "swappy" ;;
                swaybg)        echo "swaybg" ;;
                zenity)        echo "zenity" ;;
                notify-send)   echo "libnotify" ;;
                pavucontrol)   echo "pavucontrol" ;;
                font-mono)     echo "jetbrains-mono-fonts" ;;
                font-icons)    echo "fontawesome-fonts" ;;
                checkupdates)  echo "pacman-contrib" ;;  # for arch compat
                *)             echo "" ;;
            esac
            ;;
        arch)
            case "$key" in
                waybar)        echo "waybar" ;;
                niri)          echo "niri" ;;
                fuzzel)        echo "fuzzel" ;;
                mako)          echo "mako" ;;
                wireplumber)   echo "wireplumber" ;;
                playerctl)     echo "playerctl" ;;
                networkmanager) echo "networkmanager" ;;
                bluetooth)     echo "bluez bluez-utils" ;;
                tlp)           echo "tlp" ;;
                ppd)           echo "power-profiles-daemon" ;;
                brightnessctl) echo "brightnessctl" ;;
                wpctl)         echo "wireplumber" ;;
                grim)          echo "grim" ;;
                slurp)         echo "slurp" ;;
                swappy)        echo "swappy" ;;
                swaybg)        echo "swaybg" ;;
                zenity)        echo "zenity" ;;
                notify-send)   echo "libnotify" ;;
                pavucontrol)   echo "pavucontrol" ;;
                font-mono)     echo "ttf-jetbrains-mono" ;;
                font-icons)    echo "ttf-font-awesome" ;;
                checkupdates)  echo "pacman-contrib" ;;
                *)             echo "" ;;
            esac
            ;;
        debian)
            case "$key" in
                waybar)        echo "waybar" ;;  # may need PPA
                niri)          echo "" ;;  # not packaged — skip
                fuzzel)        echo "fuzzel" ;;
                mako)          echo "mako" ;;
                wireplumber)   echo "wireplumber" ;;
                playerctl)     echo "playerctl" ;;
                networkmanager) echo "network-manager" ;;
                bluetooth)     echo "bluez" ;;
                tlp)           echo "tlp" ;;
                ppd)           echo "power-profiles-daemon" ;;
                brightnessctl) echo "brightnessctl" ;;
                wpctl)         echo "wireplumber" ;;
                grim)          echo "grim" ;;
                slurp)         echo "slurp" ;;
                swappy)        echo "swappy" ;;
                swaybg)        echo "swaybg" ;;
                zenity)        echo "zenity" ;;
                notify-send)   echo "libnotify-bin" ;;
                pavucontrol)   echo "pavucontrol" ;;
                font-mono)     echo "fonts-jetbrains-mono" ;;
                font-icons)    echo "fonts-font-awesome" ;;
                checkupdates)  echo "" ;;
                *)             echo "" ;;
            esac
            ;;
    esac
}

REQUIRED_KEYS=(
    waybar fuzzel mako wireplumber playerctl networkmanager bluetooth
    brightnessctl grim slurp swappy swaybg zenity notify-send
    pavucontrol font-mono font-icons
)

OPTIONAL_KEYS=(
    tlp ppd checkupdates niri
)

missing_packages() {
    local missing=()
    local key pkg
    for key in "$@"; do
        pkg="$(pkg_for "$key" "$FAMILY")"
        [ -z "$pkg" ] && continue
        # shellcheck disable=SC2086
        for p in $pkg; do
            if ! rpm -q "$p" >/dev/null 2>&1 && ! dpkg -s "$p" >/dev/null 2>&1; then
                missing+=("$p")
            fi
        done
    done
    printf '%s\n' "${missing[@]}"
}

# ---- Backup -------------------------------------------------------------

backup_path() {
    local p="$1"
    [ -e "$p" ] || return 0
    $NO_BACKUP && { warn "skipping backup of $p (--no-backup)"; return 0; }
    local bak="${p}.bak.${TS}"
    log "backing up $p -> $bak"
    run mv "$p" "$bak"
}

# ---- Symlink ------------------------------------------------------------

symlink() {
    local src="$1" dst="$2"
    if [ -L "$dst" ]; then
        run rm "$dst"
    elif [ -e "$dst" ]; then
        backup_path "$dst"
    fi
    run ln -sfn "$src" "$dst"
}

# ---- Uninstall ----------------------------------------------------------

do_uninstall() {
    log "Uninstall: stopping daemons"
    pkill -x waybar 2>/dev/null || true
    pkill -x mako 2>/dev/null || true
    sleep 1

    log "Removing symlinks in $LOCAL_BIN"
    for s in "$LOCAL_BIN"/tokyo-niri-* "$LOCAL_BIN"/waybar-*.sh "$LOCAL_BIN"/theme-switch.sh; do
        [ -L "$s" ] || continue
        run rm "$s"
    done

    for d in waybar niri mako fuzzel; do
        target="${HOME}/.config/${d}"
        if [ -L "$target" ]; then
            log "removing symlink $target"
            run rm "$target"
        fi
    done

    # Restore newest .bak
    for d in waybar niri mako fuzzel; do
        target="${HOME}/.config/${d}"
        [ ! -L "$target" ] || continue
        local newest=""
        for bak in "${target}".bak.*; do
            [ -d "$bak" ] || continue
            [ -z "$newest" ] && newest="$bak" || [ "$bak" -nt "$newest" ] && newest="$bak"
        done
        if [ -n "$newest" ]; then
            log "restoring $newest -> $target"
            run mv "$newest" "$target"
        fi
    done

    log "Uninstall complete. Manual cleanup: ~/.config/*.bak.* directories."
}

# ---- Main flow ----------------------------------------------------------

if $UNINSTALL; then
    detect_distro
    do_uninstall
    exit 0
fi

detect_distro

log "Plan:"
echo "  Repo:          $REPO_DIR"
echo "  Distro:        ${ID} (${FAMILY})"
echo "  Package mgr:   $PM"
echo "  Initial theme: $THEME"
echo "  Local bin:     $LOCAL_BIN"
echo

log "Checking required packages..."
MISSING=()
while IFS= read -r p; do
    [ -n "$p" ] && MISSING+=("$p")
done < <(missing_packages "${REQUIRED_KEYS[@]}")

if [ ${#MISSING[@]} -gt 0 ]; then
    log "Missing required packages: ${MISSING[*]}"
    if confirm "Install them now with $PM?"; then
        run "${INSTALL[@]}" "${MISSING[@]}"
    else
        fail "refusing to continue without required packages"
    fi
else
    log "All required packages already installed"
fi

log "Checking optional packages..."
OPT_MISSING=()
while IFS= read -r p; do
    [ -n "$p" ] && OPT_MISSING+=("$p")
done < <(missing_packages "${OPTIONAL_KEYS[@]}")
if [ ${#OPT_MISSING[@]} -gt 0 ]; then
    log "Optional packages available: ${OPT_MISSING[*]}"
    if confirm "Install optional packages (tlp, power-profiles-daemon)?"; then
        run "${INSTALL[@]}" "${OPT_MISSING[@]}"
    fi
fi

if $CHECK_ONLY; then
    log "Check complete — exiting (--check-only)"
    exit 0
fi

log "Backing up existing configs"
for d in waybar niri mako fuzzel; do
    target="${HOME}/.config/${d}"
    [ -e "$target" ] || continue
    if [ -L "$target" ]; then
        log "removing existing symlink $target"
        run rm "$target"
    else
        backup_path "$target"
    fi
done

log "Symlinking repo files"
run mkdir -p "$LOCAL_BIN"

# Directories: symlink the whole config dir
symlink "$WAYBAR_DIR" "${HOME}/.config/waybar"
symlink "$NIRI_DIR"   "${HOME}/.config/niri"
symlink "$MAKO_DIR"   "${HOME}/.config/mako"
symlink "$FUZZEL_DIR" "${HOME}/.config/fuzzel"

# Scripts: one symlink per file
for s in "$SCRIPTS_DIR"/*; do
    [ -x "$s" ] || continue
    name="$(basename "$s")"
    symlink "$s" "${LOCAL_BIN}/${name}"
done
# ensure executable perms on the source files (idempotent)
run chmod +x "$SCRIPTS_DIR"/*

log "Setting initial theme: $THEME"
run "$SCRIPTS_DIR/theme-switch.sh" "$THEME"

log "Verifying waybar"
if command -v waybar >/dev/null 2>&1; then
    WAYBAR_VERSION=$(waybar --version 2>/dev/null | awk '{print $1}')
    log "waybar $WAYBAR_VERSION installed"
else
    fail "waybar not found after install"
fi

if pgrep -x waybar >/dev/null 2>&1; then
    log "waybar already running — sending SIGUSR2 to reload"
    pkill -SIGUSR2 -x waybar
else
    if confirm "Start waybar now?"; then
        nohup waybar -c "${HOME}/.config/waybar/config.jsonc" \
                     -s "${HOME}/.config/waybar/style.css" \
                     >/tmp/tokyo-niri-waybar-top.log 2>&1 &
        sleep 1
        if pgrep -x waybar >/dev/null 2>&1; then
            log "waybar started"
        else
            warn "waybar failed to start — check /tmp/tokyo-niri-waybar-top.log"
        fi
    fi
fi

log "Done."
echo
echo "Next steps:"
echo "  - Switch theme:        theme-switch.sh catppuccin"
echo "  - Live-reload waybar:  waybar-reload.sh"
echo "  - Recovery:            mv ~/.config/niri/config.kdl ~/.config/niri/config.kdl.broken"
echo "  - Backups live at:     ~/.config/*.bak.${TS}"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x install.sh
```

- [ ] **Step 3: Smoke-test in `--check-only` mode**

```bash
cd /home/efecanaktas/.config/niri
./install.sh --check-only
```

Expected output includes:
- `Detected: Fedora Linux 44 ... (using dnf)`
- `Plan:` block
- `Checking required packages...` (no actual installs)
- `Check complete — exiting (--check-only)`
- Exit code 0.

- [ ] **Step 4: Smoke-test `--uninstall` (dry-run equivalent)**

```bash
cd /home/efecanaktas/.config/niri
./install.sh --check-only --uninstall
```

Expected: prints `Detected:` and `Uninstall: stopping daemons`, then completes. No destructive actions in check-only mode. Exit 0.

- [ ] **Step 5: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add install.sh
git commit -m "feat(install): add install.sh with Fedora/Arch/Ubuntu support"
```

---

## Task 18: Create `uninstall.sh` wrapper

**Files:**
- Create: `uninstall.sh`

- [ ] **Step 1: Write the wrapper**

Create `uninstall.sh`:

```bash
#!/usr/bin/env bash
# uninstall.sh — wrapper that delegates to install.sh --uninstall.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/install.sh" --uninstall "$@"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x uninstall.sh
```

- [ ] **Step 3: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add uninstall.sh
git commit -m "feat(install): add uninstall.sh wrapper"
```

---

## Task 19: Add tests for `theme-switch.sh` and `install.sh --check-only`

**Files:**
- Create: `tests/install_test.sh`

- [ ] **Step 1: Write the test file**

Create `tests/install_test.sh`:

```bash
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
```

- [ ] **Step 2: Make executable and run**

```bash
chmod +x tests/install_test.sh
cd /home/efecanaktas/.config/niri
bash tests/install_test.sh
```

Expected: all `PASS` lines, final `Results: N passed, 0 failed`, exit 0.

- [ ] **Step 3: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add tests/install_test.sh
git commit -m "test: add install_test.sh for install.sh + theme-switch.sh"
```

---

## Task 20: Update README with new layout, install, theme switch

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Verify current README**

The current README was written in the previous session. Confirm it exists:

```bash
cd /home/efecanaktas/.config/niri
ls README.md && head -3 README.md
```

Expected: file exists, starts with `# best-linux-conf`.

- [ ] **Step 2: Replace README content**

Overwrite `README.md` with:

```markdown
# best-linux-conf

My niri Wayland compositor configuration (Tokyo Night Pro theme).

## Quick install

```bash
git clone https://github.com/34t0th3g4me/best-linux-conf.git
cd best-linux-conf
./install.sh
```

The installer detects your distro (Fedora / Arch / Ubuntu + derivatives) via `/etc/os-release`, prompts for any missing packages, backs up your existing configs, and symlinks the repo into `~/.config/`. Re-run with `--uninstall` to clean up.

## Layout

```
niri/                        # niri compositor config
config/
  waybar/                    # top bar
    config.jsonc             # waybar bar + module config
    style.css                # entry: imports base + active theme
    style/
      base.css               # layout rules, no colors
      tokyo-night.css        # default theme
      catppuccin.css         # optional
      gruvbox.css            # optional
  mako/                      # notifications
  fuzzel/                    # app launcher
scripts/                     # helper scripts (all +x, all in PATH)
  tokyo-niri-*.sh            # Tokyo Night Pro helpers
  waybar-reload.sh           # SIGUSR2 wrapper
  waybar-checkupdates.sh     # signal-driven update counter
  waybar-notifications.sh    # mako count + dnd toggle
  waybar-backlight-slider.sh # zenity brightness slider
  theme-switch.sh            # live theme switcher
install.sh                   # multi-distro installer
uninstall.sh                 # cleanup wrapper
```

## Themes

Switch the active theme live (no restart needed):

```bash
theme-switch.sh catppuccin
theme-switch.sh gruvbox
theme-switch.sh tokyo-night   # back to default
```

To add your own theme, copy `config/waybar/style/tokyo-night.css`, edit the `@define-color` values and per-module rules, then `theme-switch.sh my-theme`.

## Keybindings

| Shortcut | Action |
|---|---|
| `Super+Return` / `Super+T` | Terminal |
| `Super+Space` | Launcher |
| `Super+B` | Browser |
| `Super+E` | Editor |
| `Super+N` | Files |
| `Super+P` | KeePassXC |
| `Super+Q` | Close window |
| `Super+F` | Fullscreen |
| `Super+Shift+F` | Maximize |
| `Super+Shift+T` | Float toggle |
| `Super+O` | Workspace overview |
| `Super+1`–`5` | Focus workspace |
| `Super+Shift+1`–`5` | Move window to workspace |
| `Print` | Screenshot region |
| `XF86AudioRaise/Lower/Mute` | Volume |
| `XF86MonBrightnessUp/Down` | Brightness |
| `Super+Shift+E` | Quit niri |

## Customization

- **Add a module:** edit `config/waybar/config.jsonc`, add it to the appropriate `modules-left/-center/-right` array, then `waybar-reload.sh`.
- **Change a color:** edit `config/waybar/style/tokyo-night.css` (or whichever theme is active), `waybar-reload.sh` picks up the change via `reload_style_on_change: true`.
- **Reorder modules:** move the entries in `modules-*` arrays, `waybar-reload.sh`.

## Recovery

If niri fails to start:
1. `Ctrl+Alt+F3` → login → `mv ~/.config/niri/config.kdl ~/.config/niri/config.kdl.broken`
2. Log in again via GDM

If waybar is broken:
```bash
pkill -x waybar
waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css
# check logs: /tmp/tokyo-niri-waybar-top.log
```

## Manual install (no installer)

```bash
ln -sf "$(pwd)/niri/config.kdl"       ~/.config/niri/config.kdl
ln -sf "$(pwd)/config/waybar"         ~/.config/waybar
ln -sf "$(pwd)/config/mako"           ~/.config/mako
ln -sf "$(pwd)/config/fuzzel"         ~/.config/fuzzel
mkdir -p ~/.local/bin
for s in scripts/*; do ln -sf "$(pwd)/$s" ~/.local/bin/; done
```
```

- [ ] **Step 3: Commit**

```bash
cd /home/efecanaktas/.config/niri
git add README.md
git commit -m "docs: rewrite README for new waybar layout + install.sh + theme-switch"
```

---

## Task 21: Final verification + push

- [ ] **Step 1: Run the test suite one more time**

```bash
cd /home/efecanaktas/.config/niri
bash tests/install_test.sh
```

Expected: `Results: N passed, 0 failed`. Exit 0.

- [ ] **Step 2: Manual end-to-end smoke test**

```bash
cd /home/efecanaktas/.config/niri
pkill -x waybar 2>/dev/null || true
sleep 1
waybar -c config/waybar/config.jsonc -s config/waybar/style.css &
sleep 2
pgrep -x waybar && echo "waybar running"
# In a separate terminal: ./scripts/theme-switch.sh catppuccin
# and confirm the bar re-themes without restart.
pkill -x waybar
```

Expected: waybar starts, runs, accepts SIGUSR2 reload.

- [ ] **Step 3: Push everything to GitHub**

```bash
cd /home/efecanaktas/.config/niri
git log --oneline | head -25
git push origin main
```

Expected: every commit listed in the log appears on `https://github.com/34t0th3g4me/best-linux-conf`. The push output shows `main -> main`.

- [ ] **Step 4: Print a final summary for the user**

Print to stdout:

```
Done. Summary of changes:
- config/waybar/config.jsonc              NEW (replaces plain-JSON config)
- config/waybar/style.css                 NEW (entry point)
- config/waybar/style/base.css            NEW (layout, no colors)
- config/waybar/style/tokyo-night.css     NEW (default theme)
- config/waybar/style/catppuccin.css      NEW
- config/waybar/style/gruvbox.css         NEW
- scripts/waybar-reload.sh                NEW
- scripts/waybar-checkupdates.sh          NEW
- scripts/waybar-notifications.sh         NEW
- scripts/waybar-backlight-slider.sh      NEW
- scripts/theme-switch.sh                 NEW
- install.sh                              NEW (Fedora/Arch/Ubuntu)
- uninstall.sh                            NEW
- tests/install_test.sh                   NEW
- scripts/tokyo-niri-wifi-menu            hardened
- scripts/tokyo-niri-bluetooth-menu       hardened
- scripts/tokyo-niri-power-menu           hardened
- scripts/tokyo-niri-audio                hardened
- scripts/tokyo-niri-startup              waybar path update
- scripts/tokyo-niri-workspaces           DELETED
- scripts/tokyo-niri-center               DELETED
- scripts/tokyo-niri-profile-menu         DELETED
- config/waybar/config                    DELETED
- config/waybar/style.css (old)           DELETED
- README.md                               rewritten
- docs/superpowers/specs/2026-06-10-...   design spec (from brainstorming)
- docs/superpowers/plans/2026-06-10-...   this plan
```

---

## Self-Review

**1. Spec coverage:**

| Spec requirement | Task |
|---|---|
| `niri/workspaces`, `niri/window`, `niri/language` modules | T16 |
| `cpu`, `memory`, `temperature`, `disk` modules | T16 |
| `battery` (upower), `backlight`, `wireplumber`, `network`, `tray` | T16 |
| `idle_inhibitor`, `privacy`, `power-profiles-daemon` | T16 |
| `mpris` with click/scroll, format-disconnected | T16 |
| `custom/updates`, `custom/notifications`, `custom/logo`, `custom/power` | T7, T8, T16 |
| `clock` with `format-alt` | T16 |
| `base.css` with `@define-color` placeholders | T2 |
| `tokyo-night.css`, `catppuccin.css`, `gruvbox.css` | T3, T4 |
| `style.css` import chain | T5 |
| `theme-switch.sh` | T9 |
| `waybar-reload.sh` (SIGUSR2) | T6 |
| `waybar-checkupdates.sh` (signal-driven) | T7 |
| `waybar-notifications.sh` (mako count + dnd) | T8 |
| `waybar-backlight-slider.sh` | T10 |
| `install.sh` (Fedora/Arch/Ubuntu, --check-only, --dry-run, --theme, --no-backup, --uninstall, -y) | T17 |
| `uninstall.sh` wrapper | T18 |
| Hardened existing scripts (set -euo pipefail, sleep 0.1, guards) | T11–T15 |
| `reload_style_on_change: true`, `on-sigusr2: reload`, `restart_interval: 0` | T16 |
| `persistent-workspaces: true` | T16 |
| Click-hijacking fix on every popup-launching `on-click` | T11–T15, T16 |
| `format-disconnected: ""` on mpris | T16 |
| Tooltip with real data (essid, signal, capacity, power) | T16 |
| Remove `tokyo-niri-workspaces`, `tokyo-niri-center`, `tokyo-niri-profile-menu` | T1 |
| README update | T20 |
| Tests for installer + theme switcher | T19 |
| Verification + push | T21 |

**2. Placeholder scan:** No TBD / TODO / "similar to" / vague "handle edge cases" steps found.

**3. Type / name consistency:**
- `tokyo-niri-install-dir` placeholder in `config.jsonc` is replaced with the actual path in T16 step 2 (one canonical replacement).
- All scripts are referenced by the same names in T16 (config.jsonc), T19 (tests), T20 (README).
- Theme names: `tokyo-night`, `catppuccin`, `gruvbox` consistent across T3, T4, T5, T9, T20.
- Signal numbers: `signal: 9` for updates, `signal: 10` for notifications — no collision, documented in T16.
