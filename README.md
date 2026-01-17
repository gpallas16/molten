# Molten 🌋

A dynamic island-style shell for Hyprland built with QuickShell.

## Features

- **Dynamic Middle Bar** - Weather, date/time, notifications with contextual switching
- **App Launcher** - Favorites and all apps with search, folders support
- **Live Screen** - Calendar, events, now playing, weather
- **Notifications** - Full notification center with DND mode
- **Toolbar** - Quick toggles, brightness/volume sliders, device pickers
- **Power Menu** - Lock, suspend, reboot, shutdown, logout

## Requirements

- Hyprland >= 0.30.0
- QuickShell
- playerctl (for media controls)
- systemd (for power actions)

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/molten.git ~/.config/quickshell/molten

# Or copy to QuickShell config
cp -r molten ~/.config/quickshell/
```

## Running

```bash
# Start with QuickShell
quickshell -c ~/.config/quickshell/molten/shell.qml
```

## Configuration

Settings are stored in `~/.config/molten/settings.json`

## Project Structure

```
molten/
├── shell.qml              # Main entry point
├── HyprlandState.qml      # Global state management
├── Applications.qml       # App list management
├── Settings.qml           # Persistent settings
├── MediaController.qml    # MPRIS media controls
├── SystemTray.qml         # System tray integration
├── components/
│   ├── LeftBar.qml        # Start, overview, workspaces
│   └── RightBar.qml       # System icons, tray, power
└── screens/
    ├── AppLauncher.qml    # Application launcher
    ├── LiveScreen.qml     # Calendar, events, weather
    ├── NotificationScreen.qml
    ├── ToolbarScreen.qml  # System controls
    └── PowerScreen.qml    # Power actions
```

## Bar Behavior

- **Middle Bar**: Always visible (hidden in fullscreen)
- **Left/Right Bars**: Hidden by default, show only when no windows are active

## TODO

- [ ] Implement proper .desktop file parsing
- [ ] Add DBus notification listener
- [ ] Implement StatusNotifierItem for system tray
- [ ] Add weather API integration
- [ ] Calendar provider integration
- [ ] Liquid glass blur effect
- [ ] Drag-and-drop for favorites reordering
- [ ] Folder management UI

## License

MIT
