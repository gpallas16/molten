import QtQuick
import QtQuick.Layouts
import "../../services"

/**
 * VolumeOverlayWidget - Displays volume control slider
 * 
 * Usage:
 *   VolumeOverlayWidget {
 *       volume: Audio.volume
 *       muted: Audio.muted
 *       textColor: "#fff"
 *       onVolumeChanged: (v) => Audio.setVolume(v)
 *   }
 */
RowLayout {
    id: root
    spacing: 12
    
    // ═══════════════════════════════════════════════════════════════
    // INPUTS
    // ═══════════════════════════════════════════════════════════════
    
    // Volume state (0.0 - 1.0)
    property real volume: 0.5
    property bool muted: false
    
    // Colors (from AdaptiveColors or Theme)
    property color textColor: "#ffffff"
    property color subtleTextColor: "#888888"
    
    // Slider dimensions
    property int sliderWidth: 180
    property int sliderHeight: 8
    
    // ═══════════════════════════════════════════════════════════════
    // SIGNALS
    // ═══════════════════════════════════════════════════════════════
    
    signal volumeChangeRequested(real newVolume)
    signal volumeIncrementRequested()
    signal volumeDecrementRequested()
    signal interacted()  // User interacted, reset hide timer
    
    // ═══════════════════════════════════════════════════════════════
    // CONTENT
    // ═══════════════════════════════════════════════════════════════
    
    // Volume icon
    Text {
        id: volumeIcon
        text: {
            if (root.muted || root.volume === 0) return "🔇"
            if (root.volume < 0.33) return "🔉"
            if (root.volume < 0.66) return "🔊"
            return "🔊"
        }
        font.pixelSize: 18
        Layout.alignment: Qt.AlignVCenter
    }
    
    // Volume slider bar
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
            width: parent.width * root.volume
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
                updateVolumeFromMouse(mouse)
            }
            
            onPositionChanged: (mouse) => {
                if (pressed) {
                    updateVolumeFromMouse(mouse)
                }
            }
            
            function updateVolumeFromMouse(mouse) {
                var newVolume = Math.max(0, Math.min(1, (mouse.x - 8) / (width - 16)))
                root.volumeChangeRequested(newVolume)
                root.interacted()
            }
            
            // Scroll wheel support
            onWheel: (wheel) => {
                if (wheel.angleDelta.y > 0) {
                    root.volumeIncrementRequested()
                } else {
                    root.volumeDecrementRequested()
                }
                root.interacted()
            }
        }
    }
    
    // Volume percentage
    Text {
        text: Math.round(root.volume * 100) + "%"
        color: root.textColor
        font.pixelSize: 13
        font.weight: Font.Medium
        font.family: "monospace"
        Layout.preferredWidth: 40
        Layout.alignment: Qt.AlignVCenter
        horizontalAlignment: Text.AlignRight
    }
}
