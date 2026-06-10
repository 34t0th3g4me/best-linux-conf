# best-linux-conf

My niri Wayland compositor configuration (Tokyo Night Pro theme).

## Layout

```
niri/                        # niri compositor
  config.kdl
config/
  waybar/                    # top bar
    config
    style.css
  mako/                      # notifications
    config
  fuzzel/                    # app launcher
    fuzzel.ini
scripts/                     # tokyo-niri-* helper scripts
  tokyo-niri-audio
  tokyo-niri-bluetooth-menu
  tokyo-niri-center
  tokyo-niri-dock-app
  tokyo-niri-install
  tokyo-niri-power-menu
  tokyo-niri-profile-menu
  tokyo-niri-startup
  tokyo-niri-tlp-profile
  tokyo-niri-tlp-setup
  tokyo-niri-wallpaper
  tokyo-niri-wifi-menu
  tokyo-niri-window-menu
  tokyo-niri-workspaces
TOKYO-NIRI-PRO-README.txt    # original theme notes (untouched)
```

## Install (manual)

Symlink or copy into `~/.config/`:

```bash
ln -sf $(pwd)/niri/config.kdl ~/.config/niri/config.kdl
ln -sf $(pwd)/config/waybar ~/.config/waybar
ln -sf $(pwd)/config/mako ~/.config/mako
ln -sf $(pwd)/config/fuzzel ~/.config/fuzzel
mkdir -p ~/.local/bin
for s in scripts/tokyo-niri-*; do ln -sf "$(pwd)/$s" ~/.local/bin/; done
```

## Keybindings

| Shortcut | Action |
|---|---|
| `Super+Return` | Terminal |
| `Super+D` | Launcher |
| `Super+B` | Browser |
| `Super+E` | Zed |
| `Super+N` | Files |
| `Super+P` | KeePassXC |
| `Super+Q` | Close window |
| `Super+F` | Fullscreen |
| `Super+Shift+F` | Floating toggle |
| `Super+Shift+E` | Quit niri |

## Recovery

If niri fails to start:
1. `Ctrl+Alt+F3` → login → `mv ~/.config/niri/config.kdl ~/.config/niri/config.kdl.broken`
2. Log in again via GDM
