import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland
import "../../globals" as Root
import "../../globals"

// ═══════════════════════════════════════════════════════════════════
// Workspaces Widget - Ambxst Style
// ═══════════════════════════════════════════════════════════════════
Item {
    id: wsWidget

    // Configuration
    property int workspaceCount: 10
    property int buttonSize: 28
    property int padding: 4
    property int buttonRadius: 6
    property color accentColor: "#7eb8da"
    property color textColor: Qt.rgba(1, 1, 1, 1)
    property color occupiedColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.8)
    property color emptyColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.3)

    // State
    property int activeIndex: (Root.State.activeWorkspace - 1) % workspaceCount
    property var occupiedList: []

    // Size
    implicitWidth: buttonSize * workspaceCount + padding * 2
    implicitHeight: buttonSize + padding * 2

    // Update occupied workspaces
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: wsWidget.updateOccupied()
    }

    function updateOccupied() {
        var newList = []
        for (var i = 0; i < workspaceCount; i++) {
            newList.push(Root.State.isWorkspaceOccupied(i + 1))
        }
        occupiedList = newList
    }

    Component.onCompleted: updateOccupied()

    // Occupied range highlights (like Ambxst)
    Repeater {
        model: computeOccupiedRanges()

        Rectangle {
            required property var modelData
            x: modelData.start * buttonSize + padding
            y: padding
            width: (modelData.end - modelData.start + 1) * buttonSize
            height: buttonSize
            radius: buttonRadius
            color: Theme.current.active

            Behavior on x {
                NumberAnimation { duration: State.animDuration; easing.type: Easing.OutQuad }
            }
            Behavior on width {
                NumberAnimation { duration: State.animDuration; easing.type: Easing.OutQuad }
            }
        }
    }

    function computeOccupiedRanges() {
        var ranges = []
        var rangeStart = -1

        for (var i = 0; i < workspaceCount; i++) {
            var isOcc = occupiedList[i] || false
            if (isOcc) {
                if (rangeStart === -1) rangeStart = i
            } else {
                if (rangeStart !== -1) {
                    ranges.push({ start: rangeStart, end: i - 1 })
                    rangeStart = -1
                }
            }
        }
        if (rangeStart !== -1) {
            ranges.push({ start: rangeStart, end: workspaceCount - 1 })
        }
        return ranges
    }

    // Active workspace highlight (stretchy animation like Ambxst)
    Rectangle {
        id: activeHighlight

        property real idx1: activeIndex
        property real idx2: activeIndex
        property real margin: 3

        x: Math.min(idx1, idx2) * buttonSize + padding + margin
        y: padding + margin
        width: Math.abs(idx1 - idx2) * buttonSize + buttonSize - margin * 2
        height: buttonSize - margin * 2

        radius: height / 2
        color: accentColor

        Behavior on idx1 {
            NumberAnimation {
                duration: Root.State.animDuration / 3
                easing.type: Easing.OutSine
            }
        }

        Behavior on idx2 {
            NumberAnimation {
                duration: Root.State.animDuration
                easing.type: Easing.OutSine
            }
        }
    }

    // Workspace buttons
    Row {
        anchors.centerIn: parent

        Repeater {
            model: workspaceCount

            Button {
                id: wsButton
                property int wsId: index + 1
                property bool isActive: Root.State.activeWorkspace === wsId
                property bool isOccupied: wsWidget.occupiedList[index] || false

                width: buttonSize
                height: buttonSize
                focusPolicy: Qt.NoFocus
                hoverEnabled: true

                background: Rectangle {
                    color: "transparent"
                }

                contentItem: Item {
                    // Workspace dot
                    Rectangle {
                        anchors.centerIn: parent
                        width: 6
                        height: 6
                        radius: 3
                        color: {
                            if (wsButton.isActive) return wsWidget.accentColor
                            if (wsButton.isOccupied) return wsWidget.occupiedColor
                            return wsWidget.emptyColor
                        }
                        opacity: wsButton.hovered || wsButton.isActive || wsButton.isOccupied ? 1 : 0.5

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }
                }

                onClicked: Root.State.switchWorkspace(wsId)
            }
        }
    }

    // Scroll wheel support
    WheelHandler {
        onWheel: function(event) {
            if (event.angleDelta.y < 0) {
                Root.State.switchWorkspaceRelative(1)
            } else if (event.angleDelta.y > 0) {
                Root.State.switchWorkspaceRelative(-1)
            }
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }
}
