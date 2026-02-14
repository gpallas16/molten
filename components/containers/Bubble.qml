import QtQuick
import "../../globals"
import "."

/**
 * Bubble - Reusable bubble item with BlurContainer background
 * 
 * Automatically registers with parent BubbleField for collision detection.
 * Uses BlurContainer for consistent styling with adaptive colors.
 */
Item {
    id: bubble
    
    // Required: parent BubbleField
    property BubbleField field: null
    
    // Content
    property string icon: ""
    property bool active: false
    property bool expanded: false
    
    // Animation
    property bool show: false
    property int animIndex: 0
    property int animDuration: 300
    property real originX: 0
    property real originY: 0
    
    // Signals
    signal clicked()
    
    // Animation progress
    property real animProgress: show ? 1 : 0
    Behavior on animProgress {
        NumberAnimation {
            duration: bubble.animDuration + bubble.animIndex * 40
            easing.type: Easing.OutBack
            easing.overshoot: 1.5
        }
    }
    
    // Collision offset from field
    property var collisionOffset: field ? field.calculatePushOffset(bubble) : { x: 0, y: 0 }
    property real pushX: collisionOffset.x
    property real pushY: collisionOffset.y
    Behavior on pushX { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
    Behavior on pushY { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
    
    // Float animation
    property real floatOffset: 0
    SequentialAnimation on floatOffset {
        running: bubble.show
        loops: Animation.Infinite
        NumberAnimation { to: 3; duration: 2000 + animIndex * 200; easing.type: Easing.InOutSine }
        NumberAnimation { to: -3; duration: 2000 + animIndex * 200; easing.type: Easing.InOutSine }
    }
    
    // Transform: slide from origin + collision push + float
    transform: [
        Translate {
            x: (bubble.originX - bubble.x - bubble.width/2) * (1 - animProgress) + pushX * animProgress
            y: (bubble.originY - bubble.y - bubble.height/2) * (1 - animProgress) + pushY * animProgress + floatOffset * animProgress
        },
        Scale {
            origin.x: width / 2
            origin.y: height / 2
            xScale: animProgress
            yScale: animProgress
        }
    ]
    opacity: animProgress
    
    // Register/unregister with field
    Component.onCompleted: {
        if (field) field.registerBubble(bubble)
    }
    Component.onDestruction: {
        if (field) field.unregisterBubble(bubble)
    }
    
    // Background - BlurContainer with field's adaptive colors
    BlurContainer {
        id: bg
        anchors.fill: parent
        radius: width / 2
        highlightActive: bubble.active
        hovered: mouse.containsMouse
        backgroundIsDark: field ? field.isDark : true
        externalTextColor: field ? field.textColor : "#fff"
        externalSubtleColor: field ? field.subtleColor : "#aaa"
        externalIconColor: field ? field.iconColor : "#fff"
        
        // Active highlight overlay
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: bg.textColor
            opacity: bubble.active ? 0.15 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }
    
    // Icon
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -floatOffset * 0.3
        text: bubble.icon
        font.family: Icons.font
        font.pixelSize: bubble.width * 0.38
        color: bubble.active ? bg.textColor : bg.subtleTextColor
    }
    
    // Mouse interaction
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: bubble.clicked()
    }
}
