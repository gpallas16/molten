# Molten Theme System

## Overview

The Molten shell now has a dual-theme system with **Light** and **Dark** modes. The themes dynamically update all UI components.

## Theme Features

### Dark Theme (Default)

- Dark glass overlays with transparency
- White text and icons
- Subtle light gradients on glass surfaces
- Perfect for nighttime use

### Light Theme

- Light glass overlays with transparency
- Black text and icons
- Bright, clean appearance
- Perfect for daytime use

## How to Toggle Themes

Click the **sun/moon button** in the right bar (next to the power button):

- 🌙 = Currently in Light mode (click to switch to Dark)
- ☀ = Currently in Dark mode (click to switch to Light)

## What's Themed

Currently themed components:

- ✅ **Notch** (Dynamic Island)
- ✅ **LeftBar** (Launcher & Overview)
- ✅ **RightBar** (System Tray & Power)
- ✅ **WorkspacesWidget**

## Technical Details

### Using Themes in Custom Components

The `Theme` singleton provides access to color schemes:

```qml
import QtQuick

Rectangle {
    color: Theme.current.glassBase
    border.color: Theme.current.glassBorder

    Text {
        color: Theme.current.text
    }
}
```

### Available Theme Properties

Each theme (light/dark) provides:

**Glass/Background Colors:**

- `glassBase` - Main glass background
- `glassBorder` - Primary border color
- `glassBorderInner` - Secondary border color
- `glassExpanded` - Color for expanded state
- `gradientTop/Middle/Bottom` - Gradient stops

**Text/Icon Colors:**

- `text` - Primary text color
- `textSecondary` - Secondary/muted text
- `icon` - Icon color

**Interactive States:**

- `hover` - Hover state background
- `active` - Active/pressed state background

### Programmatic Theme Control

```qml
// Toggle theme
Theme.toggle()

// Set specific theme
Theme.mode = "light"  // or "dark"

// Check current theme
if (Theme.mode === "dark") {
    // Do dark theme specific stuff
}
```
