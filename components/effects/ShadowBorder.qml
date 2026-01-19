import QtQuick
import "../../globals"

Item {
    id: root
    
    property real radius: Theme.barRoundness
    property real shadowOpacity: 0.2
    property real shadowOffsetY: 2
    property bool flatBottom: false  // When true, bottom edge is flat (for notch attached to screen edge)
    
    anchors.fill: parent
    z: -1
    
    // Shadow layer configuration: [margin, offsetMultiplier, opacityMultiplier, borderWidth]
    readonly property var shadowLayers: [
        { margin: 3,  offsetMult: 1.0, opacityMult: 0.3, borderWidth: 3 },   // Inner
        { margin: 8,  offsetMult: 1.8, opacityMult: 0.12, borderWidth: 5 }   // Outer
    ]
    
    // Regular shadow (when not flat bottom)
    Repeater {
        model: flatBottom ? 0 : shadowLayers
        
        Rectangle {
            anchors.margins: -modelData.margin
            anchors.fill: parent
            anchors.topMargin: -modelData.margin + shadowOffsetY * modelData.offsetMult
            radius: root.radius + modelData.margin
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, shadowOpacity * modelData.opacityMult)
            border.width: modelData.borderWidth
        }
    }
    
    // Flat bottom shadow (only top and sides, no bottom)
    Repeater {
        model: flatBottom ? shadowLayers : 0
        
        Item {
            anchors.fill: parent
            anchors.margins: -modelData.margin
            anchors.topMargin: -modelData.margin + shadowOffsetY * modelData.offsetMult
            anchors.bottomMargin: -modelData.margin - 10  // Extend past bottom to hide bottom shadow
            clip: true
            
            Rectangle {
                anchors.fill: parent
                anchors.bottomMargin: -20  // Push bottom edge out of clipped area
                radius: root.radius + modelData.margin
                color: "transparent"
                border.color: Qt.rgba(0, 0, 0, shadowOpacity * modelData.opacityMult)
                border.width: modelData.borderWidth
            }
        }
    }
}
