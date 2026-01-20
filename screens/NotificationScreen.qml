import QtQuick
import QtQuick.Layouts
import "../components"
import "../globals"
import "../services"
import "../services/notification_utils.js" as NotificationUtils

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
                        text: Notifications.doNotDisturb ? "🔕" : "🔔"
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
                    onClicked: Notifications.doNotDisturb = !Notifications.doNotDisturb
                }
            }

            // Clear all
            Item {
                width: 32
                height: 32
                visible: Notifications.list.length > 0
                
         
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
                    onClicked: Notifications.discardAllNotifications()
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
                    visible: Notifications.list.length === 0

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

                // Notifications - using service list sorted by time descending
                Repeater {
                    model: Notifications.list.slice().sort((a, b) => b.time - a.time)

                    Item {
                        id: notifItem
                        width: parent.width
                        height: notifContent.implicitHeight + 24
                        
                        property var notification: modelData
                        
                        RowLayout {
                            id: notifContent
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12
                            z: 1

                            // App icon
                            Item {
                                width: 40
                                height: 40
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: adaptiveColors.subtleTextColor
                                    opacity: 0.15
                                    visible: !notifAppIcon.visible
                                }
                                
                                Image {
                                    id: notifAppIcon
                                    anchors.fill: parent
                                    source: notification && notification.appIcon ? "image://icon/" + notification.appIcon : ""
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                }
                           
                                Text {
                                    anchors.centerIn: parent
                                    text: "📬"
                                    font.pixelSize: 20
                                    z: 1
                                    visible: !notifAppIcon.visible
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    width: parent.width

                                    Text {
                                        text: notification ? notification.summary : "Notification"
                                        color: adaptiveColors.textColor
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: notification ? NotificationUtils.getFriendlyNotifTimeString(notification.time) : ""
                                        color: adaptiveColors.textColorSecondary
                                        font.pixelSize: 10
                                    }
                                }
                                
                                // App name
                                Text {
                                    text: notification && notification.appName ? notification.appName : ""
                                    color: adaptiveColors.subtleTextColor
                                    font.pixelSize: 10
                                    visible: text !== ""
                                }

                                Text {
                                    text: notification ? NotificationUtils.processNotificationBody(notification.body, notification.appName) : ""
                                    color: adaptiveColors.textColorSecondary
                                    font.pixelSize: 12
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                                
                                // Action buttons
                                RowLayout {
                                    width: parent.width
                                    spacing: 8
                                    visible: notification && notification.actions && notification.actions.length > 0 && !notification.isCached
                                    
                                    Repeater {
                                        model: notification && notification.actions ? notification.actions : []
                                        
                                        Rectangle {
                                            Layout.preferredHeight: 28
                                            Layout.fillWidth: true
                                            radius: 6
                                            color: actionArea.containsMouse ? adaptiveColors.hover : "transparent"
                                            border.width: 1
                                            border.color: adaptiveColors.subtleTextColor
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.text
                                                color: adaptiveColors.textColor
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }
                                            
                                            MouseArea {
                                                id: actionArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (notification) {
                                                        Notifications.attemptInvokeAction(notification.id, modelData.identifier, true)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Dismiss button
                            Item {
                                width: 24
                                height: 24
                                Layout.alignment: Qt.AlignTop
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: dismissArea.containsMouse ? adaptiveColors.textColor : adaptiveColors.textColorSecondary
                                    font.pixelSize: 14
                                    
                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }
                                }

                                MouseArea {
                                    id: dismissArea
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (notification) {
                                            Notifications.discardNotification(notification.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
