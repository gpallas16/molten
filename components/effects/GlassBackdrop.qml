import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../globals"
import "../effects"

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
    
    onMarginChanged: if (windowReady) updatePosition()
    
    // Y offset for animation (e.g., slide up/down)
    property real yOffset: 0
    
    // Visibility control
    property bool backdropVisible: true
    
    // Discrete mode support
    property bool discreteMode: false
    property real targetRadius: 12
    property bool flatBottom: false
    property bool notchStyle: false
    property real notchCornerSize: 12
    
    // Update Hyprland window rounding when targetRadius changes
    onTargetRadiusChanged: {
        if (windowReady) {
            var titlePattern = "title:^molten-glass-" + backdropName + "$"
            Hyprland.dispatch("exec hyprctl setprop " + titlePattern + " rounding " + Math.round(targetRadius))
        }
    }
    
    visible: !State.isFullscreen && backdropVisible
    title: "molten-glass-" + backdropName
    
    // In notch style: ears extend to sides, same height as main body
    implicitWidth: notchStyle ? targetWidth + (notchCornerSize * 2) : targetWidth
    implicitHeight: targetHeight  // Height stays same - ears are beside, not below
    
    color: "transparent"
    
    mask: Region { item: maskItem }
    
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
            var titlePattern = "title:^molten-glass-" + root.backdropName + "$"
            Hyprland.dispatch("exec hyprctl setprop " + titlePattern + " rounding " + Math.round(root.targetRadius))
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
        
        if (w <= 0 || h <= 0) return
        
        var x, y
        
        // For notch style, center calculation uses the MAIN BODY width
        var centerWidth = notchStyle ? targetWidth : w
        
        switch (horizontalAlign) {
            case "right":
                x = screenWidth - w - margin
                break
            case "center":
                // Center the main body, ears extend beyond
                x = Math.round((screenWidth - centerWidth) / 2) - (notchStyle ? notchCornerSize : 0)
                break
            default:
                x = margin
        }
        
        y = screenHeight - h - margin + Math.round(yOffset)
        
        if (y < 0) return
        
        if (x !== lastX || y !== lastY || w !== lastW || h !== lastH) {
            lastX = x; lastY = y; lastW = w; lastH = h
            var titlePattern = "title:^molten-glass-" + backdropName + "$"
            Hyprland.dispatch("movewindowpixel exact " + x + " " + y + "," + titlePattern)
            Hyprland.dispatch("resizewindowpixel exact " + w + " " + h + "," + titlePattern)
        }
    }
    
    AdaptiveColors {
        id: adaptiveColors
        region: root.backdropName
    }
    
    // Mask for window shape
    Item {
        id: maskItem
        anchors.fill: parent
        visible: false
        
        // Main body (centered horizontally)
        Rectangle {
            id: mainMask
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.notchStyle ? root.targetWidth : parent.width
            radius: root.targetRadius
            
            // Flat bottom corners
            Rectangle {
                visible: root.notchStyle || root.flatBottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: root.targetRadius
            }
        }
          
    }
    
    // Visual content
    Item {
        anchors.fill: parent
        
        Rectangle {
            id: mainRect
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.notchStyle ? root.targetWidth : parent.width
            
            color: adaptiveColors.backgroundIsDark ? 
                   Qt.rgba(0, 0, 0, 0.15) : 
                   Qt.rgba(1, 1, 1, 0.15)
            radius: root.targetRadius
            
            Rectangle {
                visible: root.notchStyle || root.flatBottom
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
}
