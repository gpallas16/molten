import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../components"
import ".."

Item {
    id: root
    implicitWidth: 350
    implicitHeight: 400

    signal closeRequested()

    // Adaptive colors based on background
    AdaptiveColors {
        id: adaptiveColors
        region: "notch"
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Quick toggles
        GridLayout {
            width: parent.width
            columns: 4
            rowSpacing: 12
            columnSpacing: 12

            Repeater {
                model: [
                    { icon: "📶", label: "WiFi", prop: "wifiEnabled" },
                    { icon: "🔵", label: "Bluetooth", prop: "bluetoothEnabled" },
                    { icon: "☕", label: "Caffeine", prop: "caffeineMode" },
                    { icon: "🎮", label: "Game Mode", prop: "gameMode" }
                ]

                Item {
                    width: 70
                    height: 70
                    

                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        z: 1

                        Text {
                            text: modelData.icon
                            font.pixelSize: 22
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: modelData.label
                            color: State[modelData.prop] ? adaptiveColors.textColor : adaptiveColors.subtleTextColor
                            font.pixelSize: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: State[modelData.prop] = !State[modelData.prop]
                    }
                }
            }
        }

        // Brightness slider
        Column {
            width: parent.width
            spacing: 8

            RowLayout {
                width: parent.width

                Text {
                    text: "☀️"
                    font.pixelSize: 16
                }
                Text {
                    text: "Brightness"
                    color: adaptiveColors.textColor
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }
                Text {
                    text: Math.round(State.brightness * 100) + "%"
                    color: adaptiveColors.subtleTextColor
                    font.pixelSize: 12
                }
            }

            Slider {
                width: parent.width
                from: 0.1
                to: 1.0
                value: State.brightness
                onMoved: State.brightness = value

                background: Item {
                    x: parent.leftPadding
                    y: parent.topPadding + parent.availableHeight / 2 - 6 / 2
                    width: parent.availableWidth
                    height: 6
                    

                    Rectangle {
                        width: parent.parent.visualPosition * parent.width
                        height: parent.height
                        radius: 3
                        color: adaptiveColors.textColor
                        z: 1
                    }
                }

                handle: Rectangle {
                    x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                    width: 18
                    height: 18
                    radius: 9
                    color: adaptiveColors.textColor
                }
            }
        }

        // Volume slider
        Column {
            width: parent.width
            spacing: 8

            RowLayout {
                width: parent.width

                Text {
                    text: {
                        if (State.volume === 0) return "🔇"
                        if (State.volume < 0.5) return "🔉"
                        return "🔊"
                    }
                    font.pixelSize: 16
                }
                Text {
                    text: "Volume"
                    color: adaptiveColors.textColor
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }
                Text {
                    text: Math.round(State.volume * 100) + "%"
                    color: adaptiveColors.subtleTextColor
                    font.pixelSize: 12
                }
            }

            Slider {
                width: parent.width
                from: 0
                to: 1.0
                value: State.volume
                onMoved: State.volume = value

                background: Item {
                    x: parent.leftPadding
                    y: parent.topPadding + parent.availableHeight / 2 - 6 / 2
                    width: parent.availableWidth
                    height: 6
                    

                    Rectangle {
                        width: parent.parent.visualPosition * parent.width
                        height: parent.height
                        radius: 3
                        color: adaptiveColors.textColor
                        z: 1
                    }
                }

                handle: Rectangle {
                    x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                    width: 18
                    height: 18
                    radius: 9
                    color: adaptiveColors.textColor
                }
            }
        }

        // Output device
        Item {
            width: parent.width
            height: 50
            
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                z: 1

                Text {
                    text: "🔈"
                    font.pixelSize: 16
                }
                Text {
                    text: "Built-in Speakers"
                    color: adaptiveColors.textColor
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
                Text {
                    text: "▼"
                    color: adaptiveColors.textColorSecondary
                    font.pixelSize: 10
                }
            }
        }

        // Input device
        Item {
            width: parent.width
            height: 50
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                z: 1

                Text {
                    text: "🎤"
                    font.pixelSize: 16
                }
                Text {
                    text: "Built-in Microphone"
                    color: adaptiveColors.textColor
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
                Text {
                    text: "▼"
                    color: adaptiveColors.textColorSecondary
                    font.pixelSize: 10
                }
            }
        }
    }
}
