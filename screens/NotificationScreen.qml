import QtQuick
import QtQuick.Layouts
import "../components"
import "../globals"

Item {
    id: root
    implicitWidth: 400
    implicitHeight: 450

    signal closeRequested()

    // Adaptive colors based on background
    AdaptiveColors {
        id: adaptiveColors
        region: "notch"
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            width: parent.width

            Text {
                text: "🔔 Notifications"
                color: adaptiveColors.textColor
                font.pixelSize: 16
                font.weight: Font.Medium
                Layout.fillWidth: true
            }

            // Do Not Disturb toggle
            Item {
                width: dndLayout.implicitWidth + 16
                height: 32
           
                RowLayout {
                    id: dndLayout
                    anchors.centerIn: parent
                    spacing: 6
                    z: 1

                    Text {
                        text: State.doNotDisturb ? "🔕" : "🔔"
                        font.pixelSize: 14
                    }
                    Text {
                        text: "DND"
                        color: adaptiveColors.textColor
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: State.doNotDisturb = !State.doNotDisturb
                }
            }

            // Clear all
            Item {
                width: 32
                height: 32
                visible: State.notifications.length > 0
                
         
                Text {
                    anchors.centerIn: parent
                    text: "🗑"
                    font.pixelSize: 14
                    z: 1
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: State.clearNotifications()
                }
            }
        }

        // Notification list
        Flickable {
            width: parent.width
            height: parent.height - 60
            clip: true
            contentHeight: notifColumn.height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: notifColumn
                width: parent.width
                spacing: 8

                // Empty state
                Item {
                    width: parent.width
                    height: 200
                    visible: State.notifications.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            text: "🔕"
                            font.pixelSize: 48
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "No notifications"
                            color: adaptiveColors.textColorSecondary
                            font.pixelSize: 14
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Notifications
                Repeater {
                    model: State.notifications

                    Item {
                        width: parent.width
                        height: notifContent.implicitHeight + 24
                        
                        RowLayout {
                            id: notifContent
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12
                            z: 1

                            Item {
                                width: 40
                                height: 40
                                
                           
                                Text {
                                    anchors.centerIn: parent
                                    text: "📬"
                                    font.pixelSize: 20
                                    z: 1
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    width: parent.width

                                    Text {
                                        text: modelData.summary || "Notification"
                                        color: adaptiveColors.textColor
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: {
                                            var now = new Date()
                                            var diff = now - modelData.timestamp
                                            var mins = Math.floor(diff / 60000)
                                            if (mins < 1) return "now"
                                            if (mins < 60) return mins + "m"
                                            var hours = Math.floor(mins / 60)
                                            if (hours < 24) return hours + "h"
                                            return Math.floor(hours / 24) + "d"
                                        }
                                        color: adaptiveColors.textColorSecondary
                                        font.pixelSize: 10
                                    }
                                }

                                Text {
                                    text: modelData.body || ""
                                    color: adaptiveColors.textColorSecondary
                                    font.pixelSize: 12
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                text: "✕"
                                color: adaptiveColors.textColorSecondary
                                font.pixelSize: 14

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: State.dismissNotification(modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
