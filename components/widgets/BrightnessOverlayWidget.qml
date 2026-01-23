import QtQuick
import QtQuick.Layouts
import "../../services"

/**
 * BrightnessOverlayWidget - Displays brightness control slider
 * Same behavior as VolumeOverlayWidget
 */
RowLayout {
    id: root
    spacing: 12
    
    // ═══════════════════════════════════════════════════════════════
    // INPUTS
    // ═══════════════════════════════════════════════════════════════
    
    // Brightness state (0.0 - 1.0)
    property real brightness: 0.8
    
    // Colors (from AdaptiveColors or Theme)
    property color textColor: "#ffffff"
    property color subtleTextColor: "#888888"
    
    // Slider dimensions
    property int sliderWidth: 180
    property int sliderHeight: 8
    
    // ═══════════════════════════════════════════════════════════════
    // SIGNALS
    // ═══════════════════════════════════════════════════════════════
    
    signal brightnessChangeRequested(real newBrightness)
    signal brightnessIncrementRequested()
    signal brightnessDecrementRequested()
    signal interacted()  // User interacted, reset hide timer
    
    // ═══════════════════════════════════════════════════════════════
    // CONTENT
    // ═══════════════════════════════════════════════════════════════
    
    // Brightness icon
    Text {
        id: brightnessIcon
        text: {
            if (root.brightness < 0.33) return "🔅"
            if (root.brightness < 0.66) return "☀️"
            return "🔆"
        }
        font.pixelSize: 18
        Layout.alignment: Qt.AlignVCenter
    }
    
    // Brightness slider bar
    Item {
        Layout.preferredWidth: root.sliderWidth
        Layout.preferredHeight: root.sliderHeight
        Layout.alignment: Qt.AlignVCenter
        
        // Background track
        Rectangle {
            anchors.fill: parent
            radius: root.sliderHeight / 2
            color: root.subtleTextColor
            opacity: 0.3
        }
        
        // Progress fill
        Rectangle {
            width: parent.width * root.brightness
            height: parent.height
            radius: root.sliderHeight / 2
            color: root.textColor
            
            Behavior on width {
                NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
            }
        }
        
        // Make slider interactive
        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            
            onPressed: (mouse) => {
                updateBrightnessFromMouse(mouse)
            }
            
            onPositionChanged: (mouse) => {
                if (pressed) {
                    updateBrightnessFromMouse(mouse)
                }
            }
            
            function updateBrightnessFromMouse(mouse) {
                var newBrightness = Math.max(0.05, Math.min(1, (mouse.x - 8) / (width - 16)))
                root.brightnessChangeRequested(newBrightness)
                root.interacted()
            }
            
            // Scroll wheel support
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) {
                    root.brightnessIncrementRequested()
                } else {
                    root.brightnessDecrementRequested()
                }
                root.interacted()
            }
        }
    }
    
    // Brightness percentage
    Text {
        text: Math.round(root.brightness * 100) + "%"
        color: root.textColor
        font.pixelSize: 13
        font.weight: Font.Medium
        font.family: "monospace"
        Layout.preferredWidth: 40
        Layout.alignment: Qt.AlignVCenter
        horizontalAlignment: Text.AlignRight
    }
}
