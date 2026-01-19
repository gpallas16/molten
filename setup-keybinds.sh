#!/bin/bash

# Molten Desktop - Keybind Setup Helper
# This script helps you set up keyboard shortcuts for Molten

set -e

MOLTEN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_CONFIG="$HOME/.config/hypr/hyprland.conf"
KEYBINDS_CONF="$MOLTEN_DIR/keybinds.conf"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🌋 Molten Keybind Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if Hyprland config exists
if [[ ! -f "$HYPR_CONFIG" ]]; then
    echo "❌ Hyprland config not found at: $HYPR_CONFIG"
    echo "   Please create it first."
    exit 1
fi

# Check if keybinds.conf exists
if [[ ! -f "$KEYBINDS_CONF" ]]; then
    echo "❌ keybinds.conf not found at: $KEYBINDS_CONF"
    echo "   This shouldn't happen. Please check your Molten installation."
    exit 1
fi

echo "📍 Molten directory: $MOLTEN_DIR"
echo "📍 Hyprland config: $HYPR_CONFIG"
echo "📍 Keybinds file: $KEYBINDS_CONF"
echo ""

# Check if already sourced
if grep -q "source.*molten.*keybinds.conf" "$HYPR_CONFIG" 2>/dev/null; then
    echo "✅ Keybinds are already configured in hyprland.conf"
    echo ""
    echo "Current line:"
    grep "source.*molten.*keybinds.conf" "$HYPR_CONFIG"
    echo ""
    read -p "Do you want to re-add it? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping..."
        exit 0
    fi
    # Remove old entry
    sed -i '/source.*molten.*keybinds.conf/d' "$HYPR_CONFIG"
fi

# Add source line
echo ""
echo "Adding keybind source to hyprland.conf..."
echo "source = $KEYBINDS_CONF" >> "$HYPR_CONFIG"

echo "✅ Done!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎹 Default Keybinds"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Super / Super+Space  →  App Launcher"
echo "  Super+N              →  Notifications"
echo "  Super+T              →  Toolbar"
echo "  Super+Shift+P        →  Power Menu"
echo "  Super+M              →  Live Activities"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Reload Hyprland config:  hyprctl reload"
echo "  2. Test by pressing Super key"
echo "  3. Customize binds in: $KEYBINDS_CONF"
echo ""
echo "For more info, see: $MOLTEN_DIR/KEYBINDS.md"
echo ""
