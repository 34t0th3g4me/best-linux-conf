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
