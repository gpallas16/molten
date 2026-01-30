import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../globals"

/**
 * GlassBackdrop - Unified blur window + content container
 * 
 * Contains both the FloatingWindow (for Hyprland blur) AND the content area.
 * They share the SAME animated size/radius - zero sync needed.
 */
Item {
    id: root
    
    // Required
    required property string backdropName
    
    // Content goes here
    default property alias content: contentArea.data
    property alias contentItem: contentArea
    
    // Shape inputs - these are the TARGET values
    property real radius: 16
    property int animationDuration: 300
    property int contentPadding: 16
    
    // Position
    property string horizontalAlign: "center"
    property int margin: 6
    property real yOffset: 0
    
    // Visibility
    property bool backdropVisible: true
    property int startupDelay: 50
    
    // Screen (from parent)
    property int screenWidth: 1920
    property int screenHeight: 1080
    
    // ═══════════════════════════════════════════════════════════════
    // TARGET SIZE - From content (no animation here)
    // ═══════════════════════════════════════════════════════════════
    readonly property real targetWidth: contentArea.children.length > 0 && contentArea.children[0].implicitWidth > 0 
                   ? contentArea.children[0].implicitWidth + contentPadding * 2 
                   : 100 + contentPadding * 2
    readonly property real targetHeight: contentArea.children.length > 0 && contentArea.children[0].implicitHeight > 0 
                    ? contentArea.children[0].implicitHeight + contentPadding * 2 
                    : 36 + contentPadding * 2
    
    // ═══════════════════════════════════════════════════════════════
    // ANIMATED VALUES - Single source of truth for BOTH blur and content
    // ═══════════════════════════════════════════════════════════════
    property real _animWidth: targetWidth
    property real _animHeight: targetHeight
    property real _animRadius: radius
    property real _animPadding: contentPadding
    
    Behavior on _animWidth {
        NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutQuart }
    }
    Behavior on _animHeight {
        NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutQuart }
    }
    Behavior on _animRadius {
        NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutQuart }
    }
    Behavior on _animPadding {
        NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutQuart }
    }
    
    // Root item uses animated size
    implicitWidth: _animWidth
    implicitHeight: _animHeight
    width: _animWidth
    height: _animHeight
    
    // ═══════════════════════════════════════════════════════════════
    // FLOATING WINDOW - For Hyprland blur effect
    // Uses the SAME animated values as content
    // ═══════════════════════════════════════════════════════════════
    FloatingWindow {
        id: blurWindow
        visible: root.backdropVisible
        title: "molten-glass-" + root.backdropName
        color: "transparent"
        
        // Use animated size
        implicitWidth: root._animWidth
        implicitHeight: root._animHeight
        
        mask: Region { item: blurMask }
        
        // Mask with animated radius
        Rectangle {
            id: blurMask
            anchors.fill: parent
            radius: root._animRadius
            visible: false
        }
        
        // Visual with animated radius
        Rectangle {
            id: blurVisual
            anchors.fill: parent
            radius: root._animRadius
            color: adaptiveColors.backgroundIsDark ? 
                   Qt.rgba(0, 0, 0, 0.15) : 
                   Qt.rgba(1, 1, 1, 0.15)
            
            Behavior on color {
                ColorAnimation { duration: 200 }
            }
        }
        
        // Position tracking
        property int lastX: -1
        property int lastY: -1
        property int lastW: -1
        property int lastH: -1
        property bool windowReady: false
        
        Timer {
            interval: root.startupDelay
            running: blurWindow.visible
            onTriggered: {
                blurWindow.windowReady = true
                blurWindow.updatePosition()
                blurWindow.updateRounding()
            }
        }
        
        // Update Hyprland rounding when animated radius changes
        onVisibleChanged: {
            if (visible && windowReady) updateRounding()
        }
        
        Connections {
            target: root
            function on_animRadiusChanged() { 
                if (blurWindow.windowReady) blurWindow.updateRounding() 
            }
        }
        
        function updateRounding() {
            var titlePattern = "title:^molten-glass-" + root.backdropName + "$"
            Hyprland.dispatch("exec hyprctl setprop " + titlePattern + " rounding " + Math.round(root._animRadius))
        }
        
        // React to animated values changing
        Connections {
            target: root
            function on_animWidthChanged() { if (blurWindow.windowReady) blurWindow.updatePosition() }
            function on_animHeightChanged() { if (blurWindow.windowReady) blurWindow.updatePosition() }
            function onYOffsetChanged() { if (blurWindow.windowReady) blurWindow.updatePosition() }
        }
        
        // Continuous update for smooth animation
        Timer {
            interval: 16
            repeat: true
            running: blurWindow.visible && blurWindow.windowReady
            onTriggered: blurWindow.updatePosition()
        }
        
        function updatePosition() {
            if (!visible || !windowReady) return
            
            // Use animated values
            var w = Math.round(root._animWidth)
            var h = Math.round(root._animHeight)
            
            if (w <= 0 || h <= 0) return
            
            var x, y
            
            switch (root.horizontalAlign) {
                case "right":
                    x = root.screenWidth - w - root.margin
                    break
                case "center":
                    x = Math.round((root.screenWidth - w) / 2)
                    break
                default:
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
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CONTENT AREA - Uses the SAME animated values
    // ═══════════════════════════════════════════════════════════════
    Item {
        id: contentArea
        x: root._animPadding
        y: root._animPadding
        width: root._animWidth - root._animPadding * 2
        height: root._animHeight - root._animPadding * 2
        clip: true
    }
    
    AdaptiveColors {
        id: adaptiveColors
        region: root.backdropName
    }
}
