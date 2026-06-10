# Waybar Redesign — Design Spec

**Date:** 2026-06-10
**Status:** Approved
**Target:** best-linux-conf repo

## Goal

Replace the current buggy, hand-rolled waybar config (and its custom `tokyo-niri-workspaces` bash parser) with a robust, feature-rich, theme-able waybar setup that ships with a multi-distro installer. The result must be:

- **Robust** — no flaky scripts, no click-hijacking, no stale data, no parser crashes
- **Feature-rich** — coverage of the standard set of system/connectivity/audio/power indicators expected on a Linux desktop in 2026
- **Theme-able** — Tokyo Night Pro default, switchable to other themes without editing JSON
- **Reproducible** — `install.sh` works on Fedora, Arch, Ubuntu (and derivatives), detects the distro, and is idempotent
- **Recoverable** — broken-config recovery is one command; uninstall restores the previous state

## Out of Scope

- Wayland compositor other than niri (config is niri-specific via `niri/*` modules but the bar itself works on Hyprland/Sway by swapping those modules)
- Custom GTK widgets
- Multi-bar setups (one bar only — `top` layer)
- Notification daemon replacement (mako stays; we only add a count indicator)

## Architecture

### File layout

```
niri/
  config.kdl                  # unchanged
config/
  waybar/
    config.jsonc              # bar + module config (JSONC: comments ok)
    style.css                 # entry point: imports base + active theme
    style/
      base.css                # @define-color neutral, layout rules
      tokyo-night.css         # default theme
      catppuccin.css          # optional
      gruvbox.css             # optional
  mako/config                 # unchanged
  fuzzel/fuzzel.ini           # unchanged
scripts/
  tokyo-niri-audio            # hardened (already has set -euo pipefail)
  tokyo-niri-bluetooth-menu   # hardened
  tokyo-niri-center           # REMOVED (replaced by niri/window)
  tokyo-niri-dock-app         # unchanged
  tokyo-niri-install          # unchanged
  tokyo-niri-power-menu       # hardened
  tokyo-niri-profile-menu     # unchanged
  tokyo-niri-startup          # hardened (already idempotent)
  tokyo-niri-tlp-profile      # unchanged
  tokyo-niri-tlp-setup        # unchanged
  tokyo-niri-wallpaper        # unchanged
  tokyo-niri-wifi-menu        # hardened
  tokyo-niri-window-menu      # unchanged
  tokyo-niri-workspaces       # REMOVED (replaced by niri/workspaces)
  waybar-reload.sh            # NEW: pkill -SIGUSR2 waybar
  waybar-checkupdates.sh      # NEW: signal-driven update check
  theme-switch.sh             # NEW: rewrite style.css include, SIGUSR2 reload
install.sh                    # NEW: detect distro, install deps, symlink
uninstall.sh                  # NEW: kill daemons, remove symlinks, restore .bak
README.md                     # updated
TOKYO-NIRI-PRO-README.txt     # unchanged
```

### Module map (top bar, height 36, margins 8/14, pill groups)

| Position | Module | Notes |
|---|---|---|
| left | `niri/workspaces` | native, `persistent-workspaces: true`, scroll=focus prev/next |
| left | `niri/window` | native, replaces `tokyo-niri-center`, `max-length: 60` |
| left | `custom/logo` | static `◆`, click=fuzzel |
| left | `clock` | `format-alt` toggle for date (right-click) |
| left | `mpris` | scroll=track, right=next, format-disconnected=`""` |
| center | `idle_inhibitor` | caffeine-style toggle |
| center | `privacy` | mic/cam/screen indicator |
| right | `custom/updates` | checkupdates, signal-driven (no polling) |
| right | `cpu` | `format: "{usage}%"`, interval 5s |
| right | `memory` | `format: "{percentage}%"`, interval 10s |
| right | `temperature` | thermal-zone, warn 70/crit 85, interval 10s |
| right | `disk` | `/`, interval 60s |
| right | `tray` | `icon-size: 16`, `show-passive-items: false` |
| right | `backlight` | `scroll-step: 5`, click=pavucontrol-style slider via script |
| right | `wireplumber` | replaces `pulseaudio`, scroll=vol, click=mute, format-icons |
| right | `network` | wifi/ethernet/offline, click=wifi-menu |
| right | `battery` (upower) | format-icons array, click=profile-menu |
| right | `power-profiles-daemon` | click=profile-menu (kept as separate badge) |
| right | `custom/notifications` | makoctl count via D-Bus, click=toggle Do Not Disturb |
| right | `custom/power` | power menu, click=sleep/lock/etc |

### Removed / replaced

- `tokyo-niri-workspaces` → **deleted** (replaced by `niri/workspaces`)
- `tokyo-niri-center` (stoic quotes) → **deleted** (replaced by `niri/window`)
- Custom `custom/profile` (TLP) → **deleted** (replaced by `power-profiles-daemon` module)
- Custom `pulseaudio` → **replaced by `wireplumber`**
- Custom battery format → **replaced by `battery` (upower) with format-icons**

### Robustness checklist (every point is a hard requirement)

1. `set -euo pipefail` at the top of every script
2. `restart_interval: 0` — no auto-restart, we want explicit SIGUSR2 reload
3. `on-sigusr2: "reload"` — live reload of config + style
4. `reload_style_on_change: true` — CSS hot-reload while editing
5. **Click-hijacking fix:** every `on-click` that launches a popup (`fuzzel`, `rofi`, `zenity`, `pavucontrol`) is prefixed with `sleep 0.1 && …`
6. **Signal-driven updates** for any custom module that reacts to events (clipboard, notifications, updates): `pkill -RTMIN+9 waybar` style updates, `exec-on-event: true`, `interval: "once"`
7. Defensive `command -v` checks in every script — graceful degradation when an optional binary is missing
8. Long intervals on heavy modules: `clock: 30`, `network: 10`, `cpu/memory/temp: 5–10`, `disk: 60`, `custom/updates: 0` (signal-driven)
9. `format-disconnected: ""` on `mpris` to hide the module when no player is active
10. `format-plugged` / `format-charging` for battery — no static `bat` text
11. Tooltips show **real data**, not generic strings (`{essid}`, `{signalStrength}`, `{capacity}% • {power}W • {time}`)
12. `persistent-workspaces: true` on `niri/workspaces` — layout stays stable when workspaces come and go
13. `tooltip: false` on popup-launching modules as a secondary click-hijacking mitigation
14. `--check-only` mode in `install.sh` to verify a system without writing anything

### CSS / theme system

**`base.css`** (always included):
- Defines neutral layout: `font-family`, `font-size`, `border: none`, `border-radius: 0`, `min-height: 0`
- `.modules-left/-center/-right`: shared pill background (alpha-blended surface), shared border, shared padding/margin
- Per-module layout rules (`#clock`, `#network`, `#battery`, …) without colors
- Uses `@define-color` placeholders for all theme values; no hardcoded hex in `base.css`

**Theme files** (each is a self-contained palette):
- `@define-color surface`, `surface-2`, `accent`, `text`
- `@define-color blue`, `purple`, `green`, `yellow`, `red`, `teal`
- Per-module color rules: `#clock { color: @blue; }`, `#battery.warning { color: @yellow; }`, etc.
- Hover rules per module: `background: alpha(@accent, 0.20); color: @text;`

**Bundled themes:**
- `tokyo-night.css` — default
- `catppuccin.css` — mocha variant
- `gruvbox.css` — dark variant

**`style.css`** is a single `@import` chain:
```css
@import url("style/base.css");
@import url("style/tokyo-night.css");
```
Active theme is chosen either by editing `style.css` (manual) or by running `scripts/theme-switch.sh <name>` (rewrites the second `@import` line and sends `SIGUSR2`).

**`theme-switch.sh <name>`** (NEW):
- Validates `<name>` is one of `tokyo-night|catppuccin|gruvbox`
- Edits `style.css` in place: replaces second `@import` line
- `pkill -SIGUSR2 waybar`
- Exits 0 on success, 1 on invalid name

### install.sh

**Entry point:** `install.sh [options]`

**Options:**
- `--check-only` — print plan, exit 0/1
- `--dry-run` — print commands without executing
- `--theme <name>` — set initial theme (default: `tokyo-night`)
- `--no-backup` — skip backup of existing config (not recommended)
- `--uninstall` — run uninstall flow instead
- `-y` / `--yes` — skip all confirmation prompts

**Flow (top to bottom, with bail-out on any error):**

1. **Pre-flight checks**
   - `bash ≥ 4` (check `$BASH_VERSION`)
   - `sudo` is available and the user can use it (cache sudo with `-v` if `-y` set)
   - `~/.local/bin` exists or can be created

2. **Distro detection**
   - `source /etc/os-release` (fallback: `/usr/lib/os-release`)
   - Match `$ID` against: `fedora`, `arch`, `manjaro`, `ubuntu`, `pop`, `debian`, `endeavouros`
   - Map to package manager: `dnf`, `pacman`, `apt`
   - Unsupported: print manual-install instructions, exit 1

3. **Package list per distro**
   - Three `declare -A` tables: `PKGS_FEDORA`, `PKGS_ARCH`, `PKGS_APT`
   - Each maps a logical key to the distro-specific package name(s)
   - Logical keys: `waybar`, `niri`, `fuzzel`, `mako`, `wireplumber`, `playerctl`, `nmcli` (in network-manager), `bluetooth`, `tlp`, `ppd` (power-profiles-daemon), `brightnessctl`, `wpctl` (in wireplumber), `grim`, `slurp`, `swappy`, `swaybg`, `zenity`, `notify-send`, `pavucontrol`, `ttf-jetbrains-mono`, `awesome-font` (or nerd font)
   - Special cases (Fedora niri is in COPR / no stable repo → note + skip), Arch niri is in `extra`
   - Run `command -v` for each, list missing packages, prompt for install (or auto with `-y`)

4. **Optional services** (separate prompt):
   - TLP: `tlp` + `tlp-rdw` + `enable tlp.service`
   - Power-profiles-daemon: `power-profiles-daemon` + `enable ppd.service`
   - Cannot have both → warn if both selected

5. **Backup**
   - For each of `~/.config/waybar`, `~/.config/niri`, `~/.config/mako`, `~/.config/fuzzel`, `~/.local/bin/tokyo-niri-*`:
     - If exists, move to `~/.config/<name>.bak.<timestamp>` (timestamp = `date +%Y%m%d-%H%M%S`)
   - Skip with `--no-backup` (print a loud warning)

6. **Symlink**
   - `~/.config/waybar` → `$REPO/config/waybar` (or copy if symlink-incompatible)
   - Same for `niri`, `mako`, `fuzzel`
   - `~/.local/bin/tokyo-niri-*` and `~/.local/bin/waybar-*.sh` and `~/.local/bin/theme-switch.sh` → `$REPO/scripts/`
   - `chmod +x` all scripts (idempotent)

7. **Theme selection**
   - Use `--theme` arg if provided, else prompt (default: `tokyo-night`)
   - Run `theme-switch.sh <name>`

8. **Verify**
   - `command -v waybar niri fuzzel mako` — all present?
   - `waybar --check` if supported (skip on versions that don't have it)
   - If `-y` not set, prompt: "Start waybar now? (y/N)"
   - On yes: `pkill -x waybar 2>/dev/null; waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css &`

9. **Print next steps + recovery**
   - `loginctl enable-linger $USER` for systemd user services
   - Recovery: `mv ~/.config/niri/config.kdl ~/.config/niri/config.kdl.broken` (existing)
   - Theme switch: `theme-switch.sh catppuccin`
   - Reload waybar live: `waybar-reload.sh`

**Error handling:**
- `set -euo pipefail` global
- `trap 'echo "interrupted, partial state in place — run with --uninstall to clean"; exit 130' INT TERM`
- After backup step: trap point changes to "restore backup on error"
- Each distro-specific function is a separate `install_fedora`, `install_arch`, `install_apt` for testability

**`uninstall.sh`** (also `--uninstall` flag):
1. `pkill -x waybar; pkill -x mako`
2. List found symlinks + `.bak.<ts>` dirs, prompt to confirm
3. `rm` symlinks
4. `mv` newest `.bak.<ts>` back to original location
5. Keep `.bak.<ts>` if no clear newest; print their paths
6. Optionally: `systemctl disable tlp power-profiles-daemon` (prompt)

## Testing / verification

Manual verification, listed in order:

1. **Dry run on Fedora 44** (current host): `./install.sh --dry-run --check-only` — print plan, no writes
2. **Install on Fedora 44**: `./install.sh -y` — symlinks, no backup, verify
3. **Reload test**: edit `style.css` color → `pkill -SIGUSR2 waybar` → bar updates within 1s
4. **Click-hijacking test**: click any popup-launching module 5 times in a row — every click should launch the popup, no captured state
5. **Persistence test**: close all apps on a workspace, switch to it — `niri/workspaces` placeholder still shows
6. **MPRIS test**: pause/stop player — `mpris` module disappears (empty `format-disconnected`)
7. **Update signal test**: `pkill -RTMIN+9 waybar` after running `checkupdates` — `custom/updates` count refreshes without polling
8. **Recovery test**: `mv ~/.config/niri/config.kdl ~/.config/niri/config.kdl.broken` — bar still works
9. **Theme switch test**: `./theme-switch.sh catppuccin` — colors change live
10. **Uninstall test**: `./uninstall.sh` — symlinks gone, `.bak.<ts>` restored

## Open questions

None at design time. All resolved during brainstorming.

## References

- [Waybar Configuration wiki](https://github.com/Alexays/Waybar/wiki/Configuration)
- [Waybar Module: Niri-Workspaces](https://github.com/Alexays/Waybar/wiki/Module:-Niri-Workspaces)
- [Waybar Module: Battery](https://github.com/Alexays/Waybar/wiki/Module:-Battery)
- [Waybar Module: PulseAudio](https://github.com/Alexays/Waybar/wiki/Module:-PulseAudio)
- [Waybar Module: Tray](https://github.com/Alexays/Waybar/wiki/Module:-Tray)
- [Waybar #1271 — SIGUSR2 reload](https://github.com/Alexays/Waybar/issues/1271)
- [Waybar #2166 — click hijacking bug](https://github.com/Alexays/Waybar/issues/2166)
- [Waybar Tray #2906 — spacing hover bug](https://github.com/Alexays/Waybar/issues/2906)
