import QtQuick
import QtQuick.Layouts
import "../../services"
import "../../services/notification_utils.js" as NotificationUtils

/**
 * NotificationPopupWidget - Displays notification popups in a bar
 * 
 * Usage:
 *   NotificationPopupWidget {
 *       notifications: Notifications.popupList
 *       textColor: "#fff"
 *       subtleTextColor: "#888"
 *       onNotificationClicked: openNotifications()
 *       onNotificationDismissed: (id) => dismissNotif(id)
 *   }
 */
Column {
    id: root
    spacing: 16
    
    // ═══════════════════════════════════════════════════════════════
    // INPUTS
    // ═══════════════════════════════════════════════════════════════
    
    // Notifications to display
    property var notifications: []
    property int maxNotifications: 10
    
    // Colors (from AdaptiveColors or Theme)
    property color textColor: "#ffffff"
    property color textColorSecondary: "#cccccc"
    property color subtleTextColor: "#888888"
    
    // Animation duration
    property int animDuration: 300
    
    // ═══════════════════════════════════════════════════════════════
    // SIGNALS
    // ═══════════════════════════════════════════════════════════════
    
    signal notificationClicked(var notification)
    signal notificationDismissed(int id)
    signal hoverStarted()
    signal hoverEnded()
    
    // ═══════════════════════════════════════════════════════════════
    // CONTENT
    // ═══════════════════════════════════════════════════════════════
    
    Repeater {
        model: root.notifications.slice(0, root.maxNotifications)
        
        delegate: Item {
            id: notifItem
            width: root.width
            // Fixed minimum height for notification item
            height: Math.max(notifRow.implicitHeight + 32, 68)
            
            required property var modelData
            required property int index
            property var notification: modelData
            
            MouseArea {
                id: notifHoverArea
                anchors.fill: parent
                hoverEnabled: true
                
                onEntered: root.hoverStarted()
                onExited: root.hoverEnded()
                onClicked: root.notificationClicked(notification)
            }
            
            RowLayout {
                id: notifRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 16
                spacing: 10
                
                // App icon
                Item {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignTop
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: root.subtleTextColor
                        opacity: 0.15
                        visible: !appIconImage.visible
                    }
                    
                    Image {
                        id: appIconImage
                        anchors.fill: parent
                        source: notification && notification.appIcon ? "image://icon/" + notification.appIcon : ""
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "📬"
                        font.pixelSize: 18
                        visible: !appIconImage.visible
                    }
                }
                
                // Notification content
                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    
                    // Header row: summary + time
                    RowLayout {
                        width: parent.width
                        spacing: 4
                        
                        Text {
                            text: notification ? notification.summary : ""
                            color: root.textColor
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        
                        Text {
                            text: notification ? NotificationUtils.getFriendlyNotifTimeString(notification.time) : ""
                            color: root.subtleTextColor
                            font.pixelSize: 10
                        }
                    }
                    
                    // Body
                    Text {
                        width: parent.width
                        text: notification ? NotificationUtils.processNotificationBody(notification.body, notification.appName) : ""
                        color: root.textColorSecondary
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
                
                // Dismiss button
                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignTop
                    
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: dismissArea.containsMouse ? root.textColor : root.subtleTextColor
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
                                root.notificationDismissed(notification.id)
                            }
                        }
                    }
                }
            }
            
            // Entry animation
            Component.onCompleted: {
                notifItem.opacity = 0
                notifItem.scale = 0.8
                entryAnim.start()
            }
            
            ParallelAnimation {
                id: entryAnim
                NumberAnimation { target: notifItem; property: "opacity"; to: 1; duration: root.animDuration; easing.type: Easing.OutQuart }
                NumberAnimation { target: notifItem; property: "scale"; to: 1; duration: root.animDuration; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }
        }
    }
}
