import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../globals"

// Reusable glass backdrop window for liquid glass effect
FloatingWindow {
    id: root
    
    // Required properties
    required property string backdropName
    required property real targetWidth
    required property real targetHeight
    required property int screenWidth
    required property int screenHeight
    
    // Position mode: "left", "right", "center"
    property string horizontalAlign: "left"
    property int margin: 6
    property int startupDelay: 50
    
    // Y offset for animation (e.g., slide up/down)
    property real yOffset: 0
    
    // Visibility control
    property bool backdropVisible: true
    
    visible: !State.isFullscreen && backdropVisible
    title: "molten-glass-" + backdropName
    
    implicitWidth: targetWidth
    implicitHeight: targetHeight
    
    color: "transparent"
    
    // Position tracking to avoid redundant Hyprland calls
    property int lastX: -1
    property int lastY: -1
    property int lastW: -1
    property int lastH: -1
    property bool windowReady: false
    
    Timer {
        interval: root.startupDelay
        running: root.visible
        onTriggered: {
            root.windowReady = true
            root.updatePosition()
        }
    }
    
    onImplicitWidthChanged: if (windowReady) updatePosition()
    onImplicitHeightChanged: if (windowReady) updatePosition()
    
    Timer {
        interval: 16
        repeat: true
        running: root.visible && root.windowReady
        onTriggered: root.updatePosition()
    }
    
    function updatePosition() {
        if (!visible || !windowReady) return
        
        var w = Math.round(implicitWidth)
        var h = Math.round(implicitHeight)
        
        // Validate dimensions - don't update if invalid
        if (w <= 0 || h <= 0) return
        
        var x, y
        
        // Calculate X position based on alignment
        switch (horizontalAlign) {
            case "right":
                x = screenWidth - w - margin
                break
            case "center":
                x = Math.round((screenWidth - w) / 2)
                break
            default: // "left"
                x = margin
        }
        
        // Y is always from bottom + yOffset for animation
        y = screenHeight - h - margin + Math.round(yOffset)
        
        // Validate Y position
        if (y < 0) return
        
        // Only dispatch if changed
        if (x !== lastX || y !== lastY || w !== lastW || h !== lastH) {
            lastX = x; lastY = y; lastW = w; lastH = h
            var titlePattern = "title:^molten-glass-" + backdropName + "$"
            Hyprland.dispatch("movewindowpixel exact " + x + " " + y + "," + titlePattern)
            Hyprland.dispatch("resizewindowpixel exact " + w + " " + h + "," + titlePattern)
        }
    }
    
    Rectangle {
        anchors.fill: parent
        color: "transparent"
    }
}
