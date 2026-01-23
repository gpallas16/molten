import QtQuick
import QtQuick.Layouts
import "../components"
import "../globals"
import "../services"
import "../services/notification_utils.js" as NotificationUtils

Item {
    id: root
    implicitWidth: 650
    implicitHeight: 450

    signal closeRequested()

    // Adaptive colors based on background
    AdaptiveColors {
        id: adaptiveColors
        region: "notch"
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Left side: Calendar + Now Playing + Weather
        Column {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            spacing: 12

            // Calendar
            Item {
                width: parent.width
                height: 200
                
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    z: 1

                    // Month/Year header
                    RowLayout {
                        width: parent.width

                        Text {
                            text: "◀"
                            color: adaptiveColors.subtleTextColor
                            font.pixelSize: 14
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendar.month = (calendar.month - 1 + 12) % 12
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: {
                                var months = ["January", "February", "March", "April", "May", "June",
                                              "July", "August", "September", "October", "November", "December"]
                                return months[calendar.month] + " " + calendar.year
                            }
                            color: adaptiveColors.textColor
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        Text {
                            text: "▶"
                            color: adaptiveColors.subtleTextColor
                            font.pixelSize: 14
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendar.month = (calendar.month + 1) % 12
                            }
                        }
                    }

                    // Day headers
                    RowLayout {
                        width: parent.width
                        spacing: 0

                        Repeater {
                            model: ["S", "M", "T", "W", "T", "F", "S"]
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                color: adaptiveColors.subtleTextColor
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Calendar grid
                    QtObject {
                        id: calendar
                        property int month: new Date().getMonth()
                        property int year: new Date().getFullYear()
                        property int today: new Date().getDate()
                        property int currentMonth: new Date().getMonth()
                        property int currentYear: new Date().getFullYear()
                    }

                    Grid {
                        width: parent.width
                        columns: 7
                        spacing: 2

                        Repeater {
                            model: {
                                var firstDay = new Date(calendar.year, calendar.month, 1).getDay()
                                var daysInMonth = new Date(calendar.year, calendar.month + 1, 0).getDate()
                                var days = []
                                
                                for (var i = 0; i < firstDay; i++) days.push(0)
                                for (var i = 1; i <= daysInMonth; i++) days.push(i)
                                
                                return days
                            }

                            Item {
                                width: 24
                                height: 24
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData > 0 ? modelData : ""
                                    color: {
                                        var isToday = modelData === calendar.today && 
                                                       calendar.month === calendar.currentMonth &&
                                                       calendar.year === calendar.currentYear
                                        return isToday ? adaptiveColors.textColor : adaptiveColors.subtleTextColor
                                    }
                                    font.pixelSize: 11
                                    z: 1
                                }
                            }
                        }
                    }
                }
            }

            // Now Playing
            Item {
                width: parent.width
                height: 70
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    z: 1

                    Item {
                        width: 44
                        height: 44
                        
                        Text {
                            anchors.centerIn: parent
                            text: State.mediaPlaying ? "🎵" : "⏸"
                            font.pixelSize: 20
                            z: 1
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: State.mediaTitle || "Nothing playing"
                            color: adaptiveColors.textColor
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: State.mediaArtist || "—"
                            color: adaptiveColors.subtleTextColor
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }
            }

            // Weather
            Item {
                width: parent.width
                height: 70

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    z: 1

                    Text {
                        text: State.weatherIcon === "weather-clear" ? "☀️" : "🌤"
                        font.pixelSize: 28
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: State.weatherTemp || "—"
                            color: adaptiveColors.textColor
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }
                        Text {
                            text: "Clear sky"
                            color: adaptiveColors.subtleTextColor
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: adaptiveColors.subtleTextColor
            opacity: 0.2
        }

        // Right side: Notifications
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.fill: parent
                spacing: 12

                // Notification Header
                RowLayout {
                    width: parent.width

                    Text {
                        text: "🔔 Notifications"
                        color: adaptiveColors.textColor
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                    }

                    // Do Not Disturb toggle
                    Item {
                        width: dndLayout.implicitWidth + 12
                        height: 28
                   
                        RowLayout {
                            id: dndLayout
                            anchors.centerIn: parent
                            spacing: 4
                            z: 1

                            Text {
                                text: Notifications.doNotDisturb ? "🔕" : "🔔"
                                font.pixelSize: 12
                            }
                            Text {
                                text: "DND"
                                color: adaptiveColors.textColor
                                font.pixelSize: 10
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
                        width: 28
                        height: 28
                        visible: Notifications.list.length > 0
                        
                        Text {
                            anchors.centerIn: parent
                            text: "🗑"
                            font.pixelSize: 12
                            z: 1
                        }

                        MouseArea {
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
                    height: parent.height - 50
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
                            height: 150
                            visible: Notifications.list.length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: 10

                                Text {
                                    text: "🔕"
                                    font.pixelSize: 36
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Text {
                                    text: "No notifications"
                                    color: adaptiveColors.textColorSecondary
                                    font.pixelSize: 12
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        // Notifications - sorted by time descending
                        Repeater {
                            model: Notifications.list.slice().sort((a, b) => b.time - a.time)

                            Item {
                                id: notifItem
                                width: parent.width
                                height: notifContent.implicitHeight + 20
                                
                                property var notification: modelData
                                
                                RowLayout {
                                    id: notifContent
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    z: 1

                                    // App icon
                                    Item {
                                        width: 36
                                        height: 36
                                        
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 6
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
                                            font.pixelSize: 16
                                            z: 1
                                            visible: !notifAppIcon.visible
                                        }
                                    }

                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        RowLayout {
                                            width: parent.width

                                            Text {
                                                text: notification ? notification.summary : "Notification"
                                                color: adaptiveColors.textColor
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: notification ? NotificationUtils.getFriendlyNotifTimeString(notification.time) : ""
                                                color: adaptiveColors.textColorSecondary
                                                font.pixelSize: 9
                                            }
                                        }
                                        
                                        // App name
                                        Text {
                                            text: notification && notification.appName ? notification.appName : ""
                                            color: adaptiveColors.subtleTextColor
                                            font.pixelSize: 9
                                            visible: text !== ""
                                        }

                                        Text {
                                            text: notification ? NotificationUtils.processNotificationBody(notification.body, notification.appName) : ""
                                            color: adaptiveColors.textColorSecondary
                                            font.pixelSize: 11
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }
                                        
                                        // Action buttons
                                        RowLayout {
                                            width: parent.width
                                            spacing: 6
                                            visible: notification && notification.actions && notification.actions.length > 0 && !notification.isCached
                                            
                                            Repeater {
                                                model: notification && notification.actions ? notification.actions : []
                                                
                                                Rectangle {
                                                    Layout.preferredHeight: 24
                                                    Layout.fillWidth: true
                                                    radius: 5
                                                    color: actionArea.containsMouse ? adaptiveColors.hover : "transparent"
                                                    border.width: 1
                                                    border.color: adaptiveColors.subtleTextColor
                                                    
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.text
                                                        color: adaptiveColors.textColor
                                                        font.pixelSize: 10
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
                                        width: 22
                                        height: 22
                                        Layout.alignment: Qt.AlignTop
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            color: dismissArea.containsMouse ? adaptiveColors.textColor : adaptiveColors.textColorSecondary
                                            font.pixelSize: 12
                                            
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
    }
}
