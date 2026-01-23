import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../globals"

/**
 * EmbeddedGlassBackdrop - Self-positioning glass backdrop for bars
 * 
 * This component creates a FloatingWindow that automatically follows
 * its parent's dimensions, position, and corner radius. It's designed
 * to be embedded inside bar components (WorkspaceBar, StatusBar, MainBar)
 * and sync automatically with their size/shape.
 * 
 * USAGE:
 *   Item {
 *       id: myBar
 *       EmbeddedGlassBackdrop {
 *           backdropName: "mybar"
 *           targetRadius: 12
 *           horizontalAlign: "left"  // or "right", "center"
 *       }
 *   }
 * 
 * The backdrop will automatically:
 * - Follow parent's implicitWidth/implicitHeight
 * - Track yOffset for slide animations
 * - Update Hyprland window rounding when radius changes
 */
Item {
    id: root
    
    // Configuration
    required property string backdropName
    property string horizontalAlign: "left"  // "left", "right", "center"
    property int margin: 6
    property int startupDelay: 50
    
    // Shape properties
    property real targetRadius: 12
    property bool flatBottom: false
    
    // Animation sync - parent should bind yPosition here
    property real yOffset: 0
    
    // Visibility control
    property bool backdropVisible: true
    
    // Explicit size overrides (use these instead of auto-sync when provided)
    property real explicitWidth: -1
    property real explicitHeight: -1
    
    // Screen dimensions - auto-detected from Hyprland
    readonly property int screenWidth: {
        var monitor = Hyprland.monitors.values[0]
        return monitor ? monitor.width : 1920
    }
    readonly property int screenHeight: {
        var monitor = Hyprland.monitors.values[0]
        return monitor ? monitor.height : 1080
    }
    
    // Parent dimensions - use explicit if provided, otherwise auto-sync from parent
    readonly property real targetWidth: explicitWidth > 0 ? explicitWidth : (parent ? parent.implicitWidth : 100)
    readonly property real targetHeight: explicitHeight > 0 ? explicitHeight : (parent ? parent.implicitHeight : 44)
    
    // The actual FloatingWindow
    FloatingWindow {
        id: glassWindow
        
        visible: root.backdropVisible
        title: "molten-glass-" + root.backdropName
        
        implicitWidth: root.targetWidth
        implicitHeight: root.targetHeight
        
        color: "transparent"
        
        mask: Region { item: maskItem }
        
        property int lastX: -1
        property int lastY: -1
        property int lastW: -1
        property int lastH: -1
        property bool windowReady: false
        
        // Reset position cache when visibility changes so window repositions properly
        onVisibleChanged: {
            if (visible) {
                // Reset cached position to force update
                lastX = -1
                lastY = -1
                lastW = -1
                lastH = -1
            }
        }
        
        // Startup delay timer
        Timer {
            interval: root.startupDelay
            running: glassWindow.visible
            onTriggered: {
                glassWindow.windowReady = true
                glassWindow.updatePosition()
                var titlePattern = "title:^molten-glass-" + root.backdropName + "$"
                Hyprland.dispatch("exec hyprctl setprop " + titlePattern + " rounding " + Math.round(root.targetRadius))
            }
        }
        
        // Update position when size changes
        onImplicitWidthChanged: if (windowReady) updatePosition()
        onImplicitHeightChanged: if (windowReady) updatePosition()
        
        // Periodic position update (handles external changes)
        Timer {
            interval: 16
            repeat: true
            running: glassWindow.visible && glassWindow.windowReady
            onTriggered: glassWindow.updatePosition()
        }
        
        function updatePosition() {
            if (!visible || !windowReady) return
            
            var w = Math.round(implicitWidth)
            var h = Math.round(implicitHeight)
            
            if (w <= 0 || h <= 0) return
            
            var x, y
            
            switch (root.horizontalAlign) {
                case "right":
                    x = root.screenWidth - w - root.margin
                    break
                case "center":
                    x = Math.round((root.screenWidth - w) / 2)
                    break
                default: // left
                    x = root.margin
            }
            
            y = root.screenHeight - h - root.margin + Math.round(root.yOffset)
            
            if (y < 0) return
            
            if (x !== lastX || y !== lastY || w !== lastW || h !== lastH) {
                lastX = x; lastY = y; lastW = w; lastH = h
                var titlePattern = "title:^molten-glass-" + root.backdropName + "$"
                Hyprland.dispatch("movewindowpixel exact " + x + " " + y + "," + titlePattern)
                Hyprland.dispatch("resizewindowpixel exact " + w + " " + h + "," + titlePattern)
            }
        }
        
        // Adaptive colors for the backdrop
        AdaptiveColors {
            id: adaptiveColors
            region: root.backdropName
        }
        
        // Mask for window shape
        Item {
            id: maskItem
            anchors.fill: parent
            visible: false
            
            Rectangle {
                anchors.fill: parent
                radius: root.targetRadius
                
                // Flat bottom corners when needed
                Rectangle {
                    visible: root.flatBottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: root.targetRadius
                }
            }
        }
        
        // Visual content - subtle tinted backdrop
        Rectangle {
            anchors.fill: parent
            color: adaptiveColors.backgroundIsDark ? 
                   Qt.rgba(0, 0, 0, 0.15) : 
                   Qt.rgba(1, 1, 1, 0.15)
            radius: root.targetRadius
            
            // Flat bottom
            Rectangle {
                visible: root.flatBottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: root.targetRadius
                color: parent.color
            }
            
            Behavior on color {
                ColorAnimation { duration: 200 }
            }
            
            Behavior on radius {
                NumberAnimation { duration: 300; easing.type: Easing.OutQuart }
            }
        }
    }
    
    // Update Hyprland window rounding when targetRadius changes
    onTargetRadiusChanged: {
        if (glassWindow.windowReady) {
            var titlePattern = "title:^molten-glass-" + backdropName + "$"
            Hyprland.dispatch("exec hyprctl setprop " + titlePattern + " rounding " + Math.round(targetRadius))
        }
    }
}
