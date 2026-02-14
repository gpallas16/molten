import QtQuick
import QtQuick.Effects
import "../../globals"
import "../effects"

/**
 * BlurContainer - Reusable container with blur background and adaptive colors
 * 
 * Same styling as MainBar - semi-transparent background + compositor blur.
 * Border is crisp, not blurred.
 */
Rectangle {
    id: container
    
    // Adaptive colors - can use shared regionId
    property string regionId: "notch"
    property bool useSharedColors: true  // If true, expects colors to be set externally
    
    // External adaptive colors (when useSharedColors is true)
    property bool backgroundIsDark: true
    property color externalTextColor: "#ffffff"
    property color externalSubtleColor: Qt.rgba(1,1,1,0.6)
    property color externalIconColor: "#ffffff"
    
    // Internal adaptive colors (when useSharedColors is false)
    AdaptiveColors {
        id: internalColors
        regionId: container.regionId
        active: !useSharedColors
    }
    
    // Expose colors for children
    readonly property bool isDark: useSharedColors ? backgroundIsDark : internalColors.backgroundIsDark
    readonly property color textColor: useSharedColors ? externalTextColor : internalColors.textColor
    readonly property color subtleTextColor: useSharedColors ? externalSubtleColor : internalColors.subtleTextColor
    readonly property color iconColor: useSharedColors ? externalIconColor : internalColors.iconColor
    
    // Appearance
    property bool highlightActive: false
    property bool hovered: false
    
    // Styling - same as MainBar: semi-transparent for compositor blur
    radius: 16
    color: {
        if (highlightActive) {
            return isDark ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.15)
        }
        return isDark ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(1, 1, 1, 0.5)
    }
    border.width: 1
    border.color: isDark ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.15)
    
    // Hover overlay
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: container.isDark ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.05)
        opacity: container.hovered ? 1 : 0
        
        Behavior on opacity { NumberAnimation { duration: 100 } }
    }
    
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }
}
