import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../globals"

/**
 * GlassBackdrop - Complete glass-styled container component
 * 
 * A unified component that provides everything needed for glass-styled views:
 * - Shape properties (radius, margin, flatBottom) with smooth animations
 * - FloatingWindow for Hyprland blur effect
 * - ShadowBorder (visual background with rounded corners)
 * 
 * Usage:
 *   GlassBackdrop {
 *       id: glassBackdrop
 *       backdropName: "myview"
 *       horizontalAlign: "center"
 *       
 *       radius: 16
 *       margin: 6
 *       flatBottom: false
 *       
 *       // Size - bind to your content
 *       contentWidth: myContent.width
 *       contentHeight: myContent.height
 *       
 *       // For slide animations
 *       yOffset: mySlideY
 *   }
 * 
 * The component handles:
 * - Animated radius transitions
 * - Backdrop blur window positioning
 * - Shadow rendering
 * - Hyprland window rounding sync
 */
Item {
    id: root
    
    // Size must match content for shadow to render correctly
    width: contentWidth
    height: contentHeight
    
    // ═══════════════════════════════════════════════════════════════
    // REQUIRED PROPERTIES
    // ═══════════════════════════════════════════════════════════════
    
    /** Unique name for the backdrop window */
    required property string backdropName
    
    // ═══════════════════════════════════════════════════════════════
    // SHAPE PROPERTIES
    // ═══════════════════════════════════════════════════════════════
    
    /** Target radius (will be animated) */
    property real radius: 16
    
    /** Margin from screen edge */
    property real margin: 6
    
    /** Whether bottom corners should be flat */
    property bool flatBottom: false
    
    // ═══════════════════════════════════════════════════════════════
    // SIZE PROPERTIES
    // ═══════════════════════════════════════════════════════════════
    
    /** Width of the content (backdrop will match this) */
    property real contentWidth: 100
    
    /** Height of the content (backdrop will match this) */
    property real contentHeight: 44
    
    // ═══════════════════════════════════════════════════════════════
    // POSITIONING
    // ═══════════════════════════════════════════════════════════════
    
    /** Horizontal alignment: "left", "center", "right" */
    property string horizontalAlign: "center"
    
    /** Y offset for slide animations */
    property real yOffset: 0
    
    // ═══════════════════════════════════════════════════════════════
    // VISIBILITY
    // ═══════════════════════════════════════════════════════════════
    
    /** Whether the backdrop should be visible */
    property bool backdropVisible: true
    
    /** Startup delay before showing backdrop (prevents flicker) */
    property int startupDelay: 50
    
    // ═══════════════════════════════════════════════════════════════
    // ANIMATION CONFIGURATION
    // ═══════════════════════════════════════════════════════════════
    
    property int animationDuration: 300
    property int easingType: Easing.OutQuart
    
    // ═══════════════════════════════════════════════════════════════
    // OUTPUT - Animated values (for external use if needed)
    // ═══════════════════════════════════════════════════════════════
    
    /** Animated radius - use this for syncing with other components */
    readonly property alias animatedRadius: internal.animRadius
    
    // ═══════════════════════════════════════════════════════════════
    // INTERNAL ANIMATION STATE
    // ═══════════════════════════════════════════════════════════════
    
    QtObject {
        id: internal
        
        property real animRadius: root.radius
        
        Behavior on animRadius {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: root.easingType
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // SCREEN DIMENSIONS
    // ═══════════════════════════════════════════════════════════════
    
    readonly property int screenWidth: {
        var monitor = Hyprland.monitors.values[0]
        return monitor ? monitor.width : 1920
    }
    readonly property int screenHeight: {
        var monitor = Hyprland.monitors.values[0]
        return monitor ? monitor.height : 1080
    }
    
    // ═══════════════════════════════════════════════════════════════
    // EMBEDDED GLASS BACKDROP - Blur window behind content
    // ═══════════════════════════════════════════════════════════════
    
    FloatingWindow {
        id: glassWindow
        
        visible: root.backdropVisible
        title: "molten-glass-" + root.backdropName
        
        implicitWidth: root.contentWidth
        implicitHeight: root.contentHeight
        
        color: "transparent"
        
        mask: Region { item: maskItem }
        
        property int lastX: -1
        property int lastY: -1
        property int lastW: -1
        property int lastH: -1
        property bool windowReady: false
        
        onVisibleChanged: {
            if (visible) {
                lastX = -1; lastY = -1; lastW = -1; lastH = -1
            }
        }
        
        Timer {
            interval: root.startupDelay
            running: glassWindow.visible
            onTriggered: {
                glassWindow.windowReady = true
                glassWindow.updatePosition()
                var titlePattern = "title:^molten-glass-" + root.backdropName + "$"
                Hyprland.dispatch("exec hyprctl setprop " + titlePattern + " rounding " + Math.round(internal.animRadius))
            }
        }
        
        onImplicitWidthChanged: if (windowReady) updatePosition()
        onImplicitHeightChanged: if (windowReady) updatePosition()
        
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
                radius: internal.animRadius
                
                Rectangle {
                    visible: root.flatBottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: internal.animRadius
                }
            }
        }
        
        // Visual content - subtle tinted backdrop
        Rectangle {
            anchors.fill: parent
            color: adaptiveColors.backgroundIsDark ? 
                   Qt.rgba(0, 0, 0, 0.15) : 
                   Qt.rgba(1, 1, 1, 0.15)
            radius: internal.animRadius
            
            Rectangle {
                visible: root.flatBottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: internal.animRadius
                color: parent.color
            }
            
            Behavior on color {
                ColorAnimation { duration: 200 }
            }
            
            Behavior on radius {
                NumberAnimation { duration: root.animationDuration; easing.type: root.easingType }
            }
        }
    }
    
    // Update Hyprland window rounding when radius changes
    onRadiusChanged: {
        if (glassWindow.windowReady) {
            var titlePattern = "title:^molten-glass-" + backdropName + "$"
            Hyprland.dispatch("exec hyprctl setprop " + titlePattern + " rounding " + Math.round(internal.animRadius))
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // SHADOW BORDER - Visual background with shadow
    // ═══════════════════════════════════════════════════════════════
    
    Item {
        id: shadowBorder
        anchors.fill: parent
        z: -1
        
        property real shadowOpacity: 0.2
        property real shadowOffsetY: 2
        
        // Shadow layer configuration
        readonly property var shadowLayers: [
            { margin: 3,  offsetMult: 1.0, opacityMult: 0.3, borderWidth: 3 },   // Inner
            { margin: 8,  offsetMult: 1.8, opacityMult: 0.12, borderWidth: 5 }   // Outer
        ]
        
        // Regular shadow (when not flat bottom)
        Repeater {
            model: root.flatBottom ? 0 : shadowBorder.shadowLayers
            
            Rectangle {
                anchors.margins: -modelData.margin
                anchors.fill: parent
                anchors.topMargin: -modelData.margin + shadowBorder.shadowOffsetY * modelData.offsetMult
                radius: internal.animRadius + modelData.margin
                color: "transparent"
                border.color: Qt.rgba(0, 0, 0, shadowBorder.shadowOpacity * modelData.opacityMult)
                border.width: modelData.borderWidth
            }
        }
        
        // Flat bottom shadow (only top and sides, no bottom)
        Repeater {
            model: root.flatBottom ? shadowBorder.shadowLayers : 0
            
            Item {
                anchors.fill: parent
                anchors.margins: -modelData.margin
                anchors.topMargin: -modelData.margin + shadowBorder.shadowOffsetY * modelData.offsetMult
                anchors.bottomMargin: -modelData.margin - 10
                clip: true
                
                Rectangle {
                    anchors.fill: parent
                    anchors.bottomMargin: -20
                    radius: internal.animRadius + modelData.margin
                    color: "transparent"
                    border.color: Qt.rgba(0, 0, 0, shadowBorder.shadowOpacity * modelData.opacityMult)
                    border.width: modelData.borderWidth
                }
            }
        }
    }
}
