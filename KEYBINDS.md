# Molten Desktop - Keyboard Shortcuts Guide

This document explains how keyboard shortcuts work in Molten and how to customize them.

## How It Works

Molten uses a **named pipe (FIFO)** for IPC communication, similar to Ambxst. When you press a keyboard shortcut, Hyprland writes the command to the pipe, and Molten's KeybindHandler reads and processes it.

### Architecture

1. **KeybindHandler** creates a named pipe at `/tmp/molten_ipc.pipe`
2. **Hyprland keybind** → writes command to pipe using `echo "command" > /tmp/molten_ipc.pipe`
3. **KeybindHandler** → reads from pipe and emits signal
4. **Shell.qml** → receives signal and opens the appropriate view

This approach is simple, fast, and doesn't require external dependencies like `socat` or `netcat`.

## Default Keybinds

| Shortcut                   | Action                        |
| -------------------------- | ----------------------------- |
| `Super` or `Super + Space` | Open App Launcher             |
| `Super + N`                | Open Notifications            |
| `Super + T`                | Open Toolbar (Quick Settings) |
| `Super + Shift + P`        | Open Power Menu               |
| `Super + M`                | Open Live Activities/Media    |

## Customizing Shortcuts

### Method 1: Edit keybinds.conf

Edit [`keybinds.conf`](keybinds.conf) and add/modify bindings:

```conf
# Format: bind = MODIFIERS, KEY, exec, echo "ACTION" > /tmp/molten_ipc.pipe
bind = SUPER, Space, exec, echo "launcher" > /tmp/molten_ipc.pipe
```

Available actions:

- `launcher` - App launcher
- `notifications` - Notification center
- `toolbar` - Quick settings toolbar
- `power` - Power menu
- `live` - Live activities/media controls

### Method 2: Add to your Hyprland config

You can also add keybinds directly to your `~/.config/hypr/hyprland.conf`:

```conf
# Source the Molten keybinds
source = ~/.config/molten/keybinds.conf

# Or add custom bindings directly
bind = SUPER, A, exec, echo "launcher" > /tmp/molten_ipc.pipe
bind = CTRL ALT, N, exec, echo "notifications" > /tmp/molten_ipc.pipe
```

### Supported Modifiers

- `SUPER` (Windows key)
- `ALT`
- `CTRL`
- `SHIFT`
- Combine with spaces: `SUPER SHIFT`, `CTRL ALT`, etc.

## Adding New Actions

To add a custom action:

1. **Add keybind** in `keybinds.conf`:

   ```conf
   bind = SUPER, Y, exec, echo "my_custom_action" > /tmp/molten_ipc.pipe
   ```

2. **Handle it** in [`shell.qml`](shell.qml):
   ```qml
   Connections {
       target: Root.KeybindHandler

       function onKeybindTriggered(action) {
           switch (action) {
               case "my_custom_action":
                   // Your custom code here
                   console.log("Custom action triggered!")
                   break
               // ... other cases
           }
       }
   }
   ```

## Troubleshooting

### Shortcuts not working?

1. **Check if keybinds.conf is sourced:**

   ```bash
   grep "molten/keybinds.conf" ~/.config/hypr/hyprland.conf
   ```

2. **Reload Hyprland config:**

   ```bash
   hyprctl reload
   ```

3. **Check if pipe exists and has correct permissions:**

   ```bash
   ls -l /tmp/molten_ipc.pipe
   # Should show: prw------- (named pipe)
   ```

4. **Test the pipe manually:**

   ```bash
   echo "launcher" > /tmp/molten_ipc.pipe
   ```

   The app launcher should open. If nothing happens, check Quickshell logs.

5. **Check Quickshell logs:**
   Look for "KeybindHandler: Received molten action" messages.

### Conflicts with other apps?

If a shortcut is already used by another application, Hyprland will prioritize its own binds. You can:

- Choose a different key combination
- Use the `l` flag for locked binds (work even when locked)
- Use the `e` flag for repeat binds

Example:

```conf
bind = SUPER, Space, global, molten:launcher  # Regular
bindl = SUPER, N, global, molten:notifications  # Works when locked
```

## Notes

- The `Super_L` key (left Super key) is commonly used to open app launchers on most desktop environments
- You can have multiple keybinds trigger the same action
- Hyprland processes keybinds in order, so more specific binds should come first
