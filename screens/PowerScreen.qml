import QtQuick
import QtQuick.Layouts
import "../components"
import "../globals"

Item {
    id: root
    implicitWidth: 400
    implicitHeight: 150

    signal closeRequested()

    // Adaptive colors based on background
    AdaptiveColors {
        id: adaptiveColors
        region: "notch"
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 24

        Repeater {
            model: [
                { icon: "🔒", label: "Lock", action: "lock" },
                { icon: "😴", label: "Suspend", action: "suspend" },
                { icon: "🔄", label: "Reboot", action: "reboot" },
                { icon: "⏻", label: "Shutdown", action: "shutdown" },
                { icon: "🚪", label: "Logout", action: "logout" }
            ]

            Item {
                width: 70
                height: 90
                
               

                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    z: 1

                    Text {
                        text: modelData.icon
                        font.pixelSize: 28
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: modelData.label
                        color: adaptiveColors.textColor
                        font.pixelSize: 11
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        switch(modelData.action) {
                            case "lock": State.powerLock(); break
                            case "suspend": State.powerSuspend(); break
                            case "reboot": State.powerReboot(); break
                            case "shutdown": State.powerShutdown(); break
                            case "logout": State.powerLogout(); break
                        }
                        root.closeRequested()
                    }
                }
            }
        }
    }
}
