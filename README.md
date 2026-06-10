# best-linux-conf

My niri Wayland compositor configuration (Tokyo Night Pro theme).

## Quick install

```bash
git clone https://github.com/34t0th3g4me/best-linux-conf.git
cd best-linux-conf
./install.sh
```

The installer detects your distro family (Fedora / Arch / Debian-Ubuntu / openSUSE, including derivatives via `ID_LIKE`) from `/etc/os-release`, maps packages to their distro-specific names (e.g. `mako` is `mako-notifier` on Ubuntu), prompts for any missing ones, backs up your existing configs, and symlinks the repo into `~/.config/`. Packages that aren't in your repos are reported and skipped instead of aborting the install — `swappy` is optional (not packaged on Ubuntu 24.04; screenshots fall back to save + clipboard). Re-run with `--uninstall` to clean up.

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
  xdg-desktop-portal/        # portal config: screen sharing in niri sessions
scripts/                     # helper scripts (all +x, all in PATH)
  tokyo-niri-*.sh            # Tokyo Night Pro helpers
  waybar-reload.sh           # SIGUSR2 wrapper
  waybar-checkupdates.sh     # signal-driven update counter + distro-aware upgrade
  waybar-notifications.sh    # mako count + dnd toggle
  waybar-backlight-slider.sh # zenity brightness slider
  waybar-microphone.sh       # mic volume/mute module
  theme-switch.sh            # live theme switcher
  tokyo-niri-screenshot      # region screenshot, swappy optional
  tokyo-niri-audio-menu      # GNOME-style output/input device switcher
  tokyo-niri-lock            # themed lock screen (blurred screenshot bg)
install.sh                   # multi-distro installer
uninstall.sh                 # cleanup wrapper
```

## Audio quick controls

GNOME-style switching straight from the bar — no pavucontrol needed for
the common case:

- **Click the volume module** → fuzzel menu with all outputs *and* inputs;
  pick one to make it the default (`wpctl set-default`). Mute toggles and
  pavucontrol are in the same menu.
- **Microphone module** next to it: click = mute toggle, right-click =
  device switcher, scroll = input volume.
- Middle-click the volume module for the zenity slider.

## Lock screen

`tokyo-niri-lock` (bound to `Super+L`, also used by the power menu,
`loginctl lock-session`, idle timeout, and before suspend):

- Per-output **blurred + dimmed screenshot** background (grim + imagemagick),
  Tokyo Night themed swaylock indicator ring.
- Custom lock wallpaper: put an image at `~/.config/tokyo-niri/lock-wallpaper`
  (or set `$TOKYO_NIRI_LOCK_WALLPAPER`).
- swayidle locks after 10 min idle, turns displays off 1 min later, and
  always locks before suspend.

The desktop wallpaper works the same way: `~/.config/tokyo-niri/wallpaper`,
`$TOKYO_NIRI_WALLPAPER`, or `<Pictures>/wallpaper.jpg|png`.

## Screen sharing

niri sessions use `xdg-desktop-portal-gnome` for screencast (niri speaks the
Mutter ScreenCast API over PipeWire) — `config/xdg-desktop-portal/niri-portals.conf`
is symlinked into place and only applies when `XDG_CURRENT_DESKTOP=niri`, so
a GNOME session on the same machine keeps its own portal setup. The installer
pulls `xdg-desktop-portal-gnome`, `-gtk`, and PipeWire; the startup script
pushes `WAYLAND_DISPLAY` into the D-Bus activation environment so portals
find the compositor.

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
| `Super+L` | Lock screen |
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
