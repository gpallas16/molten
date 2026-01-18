import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root
    implicitWidth: mainRow.implicitWidth
    implicitHeight: 44

    signal powerRequested()
    signal toolbarRequested()

    // Auto-hide state (controlled by parent)
    property bool showBar: false
    
    // Y position for glass backdrop sync - use binding to always match transform
    property real yPosition: slideTransform.y
    
    // Slide animation: translate Y when hiding
    transform: Translate {
        id: slideTransform
        y: showBar ? 0 : (root.height + 20)
        
        Behavior on y {
            NumberAnimation {
                duration: 400
                easing.type: showBar ? Easing.OutBack : Easing.InQuad
                easing.overshoot: 1.2
            }
        }
    }
    
    opacity: showBar ? 1.0 : 0.0
    
    Behavior on opacity {
        NumberAnimation {
            duration: showBar ? 300 : 200
            easing.type: Easing.InOutQuad
        }
    }
    
    // Adaptive colors based on background
    AdaptiveColors {
        id: adaptiveColors
        region: "right"
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

    Row {
        id: mainRow
        anchors.centerIn: parent
        spacing: 8

        // System tray island
        Item {
            width: trayLayout.implicitWidth + 20
            height: 44

            RowLayout {
                id: trayLayout
                anchors.centerIn: parent
                spacing: 6

                // Volume indicator
                Item {
                    width: 28
                    height: 28
                    
                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (State.volume === 0) return "🔇"
                            if (State.volume < 0.5) return "🔉"
                            return "🔊"
                        }
                        font.pixelSize: 15
                        color: adaptiveColors.iconColor
                    }
                }

                // Network indicator  
                Item {
                    width: 28
                    height: 28
                    
                    Text {
                        anchors.centerIn: parent
                        text: State.wifiEnabled ? "📶" : "📵"
                        font.pixelSize: 15
                        color: adaptiveColors.iconColor
                    }
                }

                // Bluetooth
                Item {
                    width: 28
                    height: 28
                    visible: State.bluetoothEnabled !== undefined ? State.bluetoothEnabled : false
                    
                    Text {
                        anchors.centerIn: parent
                        text: "🔷"
                        font.pixelSize: 13
                        color: adaptiveColors.iconColor
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toolbarRequested()
            }
        }

        // Theme toggle island
        Item {
            width: 44
            height: 44

            Text {
                anchors.centerIn: parent
                text: Theme.mode === "dark" ? "☀" : "🌙"
                font.pixelSize: 16
            }

            MouseArea {
                id: themeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Theme.toggle()
            }
        }

        // Power island
        Item {
            width: 44
            height: 44


            Text {
                anchors.centerIn: parent
                text: "⏻"
                font.pixelSize: 16
                color: powerMouse.containsMouse ? "#ff6b6b" : adaptiveColors.iconColor
            }

            MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.powerRequested()
            }
        }
    }
}
