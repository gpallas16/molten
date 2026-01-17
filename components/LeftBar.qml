import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."

Item {
    id: root
    implicitWidth: layout.implicitWidth + 24
    implicitHeight: 44

    signal launcherRequested()
    signal overviewRequested()

    // Auto-hide state (controlled by parent)
    property bool showBar: false
    opacity: showBar ? 1.0 : 0.0
    
    // Adaptive colors based on background
    AdaptiveColors {
        id: adaptiveColors
        region: "left"
    }
    
    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    ShadowBorder {
        radius: Theme.barRoundness
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        // Start icon (app launcher)
        Rectangle {
            width: 34
            height: 34
            radius: Theme.barRoundness / 2
            color: startMouse.containsMouse ? Theme.current.hover : "transparent"

            Image {
                anchors.centerIn: parent
                source: "image://icon/nix-snowflake"
                sourceSize: Qt.size(22, 22)
                width: 22
                height: 22
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                text: "❄"
                font.pixelSize: 18
                color: adaptiveColors.iconColor
                visible: parent.children[0].status !== Image.Ready
            }

            MouseArea {
                id: startMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launcherRequested()
            }
        }

        // Overview button
        Rectangle {
            width: 34
            height: 34
            radius: 10
            color: overviewMouse.containsMouse ? Theme.current.hover : "transparent"

            Text {
                anchors.centerIn: parent
                text: "▦"
                font.pixelSize: 16
                color: adaptiveColors.iconColor
            }

            MouseArea {
                id: overviewMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.overviewRequested()
            }
        }

        // Workspaces Widget (Ambxst-style)
        WorkspacesWidget {
            id: workspacesWidget
            textColor: adaptiveColors.iconColor
        }
    }
}
