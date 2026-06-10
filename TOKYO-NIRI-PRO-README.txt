Tokyo Night Pro for niri

Files:
- ~/.config/niri/config.kdl
- ~/.config/waybar/config
- ~/.config/waybar/style.css
- ~/.config/waybar-dock/config
- ~/.config/waybar-dock/style.css
- ~/.config/mako/config
- ~/.config/fuzzel/fuzzel.ini
- ~/.local/bin/tokyo-niri-startup
- ~/.local/bin/tokyo-niri-wallpaper
- ~/.local/bin/tokyo-niri-dock-app

Runtime logs:
- /tmp/tokyo-niri-waybar-top.log
- /tmp/tokyo-niri-waybar-dock.log
- /tmp/tokyo-niri-mako.log
- /tmp/tokyo-niri-wallpaper.log

If niri does not start:
1. Press Ctrl+Alt+F3
2. Login
3. Run: mv ~/.config/niri/config.kdl ~/.config/niri/config.kdl.broken
4. Login again through GDM

Restore backup:
./tokyo-niri-pro.sh --restore

Shortcuts:
- Super+Return: terminal
- Super+D: launcher
- Super+B: browser
- Super+E: Zed
- Super+N: files
- Super+P: KeePassXC
- Super+Q: close window
- Super+F: fullscreen
- Super+Shift+F: floating toggle
- Super+Shift+E: quit niri
