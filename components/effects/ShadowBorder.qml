import QtQuick
import "../.."

Item {
    id: root
    
    property real radius: Theme.barRoundness
    property real shadowOpacity: 0.6
    property real shadowOffsetY: 2
    
    anchors.fill: parent
    z: -1
    
    // Shadow layer configuration: [margin, offsetMultiplier, opacityMultiplier, borderWidth]
    readonly property var shadowLayers: [
        { margin: 2,  offsetMult: 1.0, opacityMult: 0.25, borderWidth: 3 },  // Inner
        { margin: 5,  offsetMult: 1.5, opacityMult: 0.15, borderWidth: 4 },  // Middle
        { margin: 10, offsetMult: 2.0, opacityMult: 0.08, borderWidth: 6 }   // Outer
    ]
    
    Repeater {
        model: shadowLayers
        
        Rectangle {
            anchors.fill: parent
            anchors.margins: -modelData.margin
            anchors.topMargin: -modelData.margin + shadowOffsetY * modelData.offsetMult
            radius: root.radius + modelData.margin
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, shadowOpacity * modelData.opacityMult)
            border.width: modelData.borderWidth
        }
    }
}
