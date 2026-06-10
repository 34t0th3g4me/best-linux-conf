# best-linux-conf

My niri Wayland compositor configuration (Tokyo Night Pro theme).

## Contents

- `config.kdl` — niri compositor config
- `TOKYO-NIRI-PRO-README.txt` — original theme notes

## Related configs (not tracked here, see local paths)

- `~/.config/waybar/config`
- `~/.config/waybar/style.css`
- `~/.config/waybar-dock/config`
- `~/.config/waybar-dock/style.css`
- `~/.config/mako/config`
- `~/.config/fuzzel/fuzzel.ini`
- `~/.local/bin/tokyo-niri-startup`
- `~/.local/bin/tokyo-niri-wallpaper`
- `~/.local/bin/tokyo-niri-dock-app`

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
