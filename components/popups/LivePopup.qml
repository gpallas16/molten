import QtQuick
import QtQuick.Layouts
import "../../globals"
import "../../services"
import "../../services/notification_utils.js" as NotificationUtils
import "../effects"
import "../containers"

/**
 * LivePopup - Bubble layout for live info:
 *   Left:    Clock → Calendar (TransformBubble)
 *   Center:  Now Playing, Weather
 *   Right:   Notifications (TransformBubble)
 */
Item {
    id: root

    property bool show: false
    property int animDuration: State.animDuration ?? 300

    signal closeRequested()

    implicitWidth: 580
    implicitHeight: 380
    width: implicitWidth
    height: implicitHeight

    readonly property real originX: 0
    readonly property real originY: implicitHeight

    property int screenX: 0
    property int screenY: 0

    // ── Container ─────────────────────────────────────────────────
    BubbleContainer {
        id: bubbleContainer
        anchors.fill: parent
        show: root.show
        animDuration: root.animDuration
        originX: root.originX
        originY: root.originY
        screenX: root.screenX
        screenY: root.screenY
    }

    // ── Expose colors ─────────────────────────────────────────────
    readonly property bool isDark: bubbleContainer.isDark
    readonly property color textColor: bubbleContainer.textColor
    readonly property color subtleColor: bubbleContainer.subtleColor
    readonly property color iconColor: bubbleContainer.iconColor

    // ═════════════════════════════════════════════════════════════════
    // BUBBLES — Organic scatter layout
    //
    //     ┌──────────┐
    //     │  Clock   │    ┌────┐
    //     │  (TB)    │    │ W  │     ┌──────────┐
    //     └──────────┘    └────┘     │  Notif   │
    //                                │  (TB)    │
    //        ┌───────────────┐       └──────────┘
    //        │  Now Playing   │
    //        └───────────────┘
    // ═════════════════════════════════════════════════════════════════

    // ── Clock → Calendar (TransformBubble) ────────────────────────
    TransformBubble {
        id: clockBubble
        parent: bubbleContainer
        itemId: "clock"
        itemX: 90;  itemY: 100
        itemWidth: 110;  itemHeight: 110
        animIndex: 0
        expandedWidth: 280
        expandedHeight: 310
        expandCenterX: root.implicitWidth / 2
        expandCenterY: expandedHeight / 2 + 12

        ClockCalendarContent {
            anchors.fill: parent
            expanded: clockBubble.isFocused
        }
    }

    // ── Weather ───────────────────────────────────────────────────
    Bubble {
        parent: bubbleContainer
        itemId: "weather"
        itemX: 235;  itemY: 80
        itemWidth: 72;  itemHeight: 72
        animIndex: 1

        WeatherContent {
            anchors.fill: parent
            focused: parent.isFocused
        }
    }

    // ── Now Playing ───────────────────────────────────────────────
    Bubble {
        parent: bubbleContainer
        itemId: "media"
        itemX: 180;  itemY: 250
        itemWidth: 185;  itemHeight: 60
        animIndex: 2

        MediaContent {
            anchors.fill: parent
            focused: parent.isFocused
        }
    }

    // ── Notifications (TransformBubble) ───────────────────────────
    TransformBubble {
        id: notifBubble
        parent: bubbleContainer
        itemId: "notifications"
        itemX: 450;  itemY: 140
        itemWidth: 115;  itemHeight: 60
        animIndex: 3
        expandedWidth: 330
        expandedHeight: 350
        expandCenterX: root.implicitWidth / 2
        expandCenterY: expandedHeight / 2 + 12

        NotificationListContent {
            anchors.fill: parent
            expanded: notifBubble.isFocused
        }
    }

    // ═════════════════════════════════════════════════════════════════
    // CONTENT COMPONENTS
    // ═════════════════════════════════════════════════════════════════

    // ── Clock → Calendar ──────────────────────────────────────────
    component ClockCalendarContent: Item {
        id: clockCalContent
        property bool expanded: false

        BlurContainer {
            anchors.fill: parent
            radius: clockCalContent.expanded ? 16 : Math.min(width, height) / 2
            hovered: clockCalContent.expanded
            backgroundIsDark: root.isDark
            externalTextColor: root.textColor
            externalSubtleColor: root.subtleColor
            externalIconColor: root.iconColor
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
        }

        Timer {
            interval: 30000; running: root.show; repeat: true
            onTriggered: {} // Bindings auto-update via new Date()
        }

        QtObject {
            id: cal
            property int month: new Date().getMonth()
            property int year: new Date().getFullYear()
            property int today: new Date().getDate()
            property int currentMonth: new Date().getMonth()
            property int currentYear: new Date().getFullYear()
        }

        // Collapsed: clock face
        Column {
            anchors.centerIn: parent
            spacing: 2
            visible: !clockCalContent.expanded
            opacity: clockCalContent.expanded ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(new Date(), "hh:mm")
                color: root.textColor
                font.pixelSize: 26
                font.weight: Font.Bold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(new Date(), "ddd, MMM d")
                color: root.subtleColor
                font.pixelSize: 11
            }
        }

        // Expanded: clock header + calendar grid
        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6
            visible: clockCalContent.expanded
            opacity: clockCalContent.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // Time + date header
            Column {
                width: parent.width
                spacing: 2

                Text {
                    text: Qt.formatTime(new Date(), "hh:mm")
                    color: root.textColor
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }
                Text {
                    text: Qt.formatDate(new Date(), "dddd, MMMM d")
                    color: root.subtleColor
                    font.pixelSize: 11
                }
            }

            // Separator
            Rectangle {
                width: parent.width
                height: 1
                color: root.isDark ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.06)
            }

            // Month header with nav arrows
            RowLayout {
                width: parent.width

                Text {
                    text: Icons.caretLeft
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: root.subtleColor
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cal.month--
                            if (cal.month < 0) { cal.month = 11; cal.year-- }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        var months = ["January","February","March","April","May","June",
                                      "July","August","September","October","November","December"]
                        return months[cal.month] + " " + cal.year
                    }
                    color: root.textColor
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Text {
                    text: Icons.caretRight
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: root.subtleColor
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cal.month++
                            if (cal.month > 11) { cal.month = 0; cal.year++ }
                        }
                    }
                }
            }

            // Day-of-week headers
            Row {
                width: parent.width
                Repeater {
                    model: ["S","M","T","W","T","F","S"]
                    Text {
                        width: parent.width / 7
                        text: modelData
                        color: root.subtleColor
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Day grid
            Grid {
                width: parent.width
                columns: 7
                Repeater {
                    model: {
                        var first = new Date(cal.year, cal.month, 1).getDay()
                        var days = new Date(cal.year, cal.month + 1, 0).getDate()
                        var arr = []
                        for (var i = 0; i < first; i++) arr.push(0)
                        for (var d = 1; d <= days; d++) arr.push(d)
                        return arr
                    }

                    Item {
                        width: parent.width / 7
                        height: 26

                        Rectangle {
                            anchors.centerIn: parent
                            width: 22; height: 22; radius: 11
                            visible: modelData === cal.today &&
                                     cal.month === cal.currentMonth &&
                                     cal.year === cal.currentYear
                            color: root.isDark ? Qt.rgba(1,1,1,0.15) : Qt.rgba(0,0,0,0.1)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData > 0 ? modelData : ""
                            color: {
                                var isToday = modelData === cal.today &&
                                              cal.month === cal.currentMonth &&
                                              cal.year === cal.currentYear
                                return isToday ? root.textColor : root.subtleColor
                            }
                            font.pixelSize: 10
                            font.weight: {
                                var isToday = modelData === cal.today &&
                                              cal.month === cal.currentMonth &&
                                              cal.year === cal.currentYear
                                return isToday ? Font.Bold : Font.Normal
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Weather ───────────────────────────────────────────────────
    component WeatherContent: Item {
        id: weatherContent
        property bool focused: false

        BlurContainer {
            anchors.fill: parent
            radius: width / 2
            hovered: weatherContent.focused
            backgroundIsDark: root.isDark
            externalTextColor: root.textColor
            externalSubtleColor: root.subtleColor
            externalIconColor: root.iconColor
        }

        Column {
            anchors.centerIn: parent
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Icons.sun
                font.family: Icons.font
                font.pixelSize: 22
                color: root.iconColor
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: State.weatherTemp || "—"
                color: root.textColor
                font.pixelSize: 15
                font.weight: Font.Bold
            }
        }
    }

    // ── Now Playing ───────────────────────────────────────────────
    component MediaContent: Item {
        id: mediaContent
        property bool focused: false

        BlurContainer {
            anchors.fill: parent
            radius: height / 2
            hovered: mediaContent.focused
            backgroundIsDark: root.isDark
            externalTextColor: root.textColor
            externalSubtleColor: root.subtleColor
            externalIconColor: root.iconColor
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Text {
                text: State.mediaPlaying ? Icons.play : Icons.pause
                font.family: Icons.font
                font.pixelSize: 18
                color: root.iconColor
            }

            Column {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: State.mediaTitle || "Nothing playing"
                    color: root.textColor
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: State.mediaArtist || "—"
                    color: root.subtleColor
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }
    }

    // ── Notification list content ────────────────────────────────
    component NotificationListContent: Item {
        id: notifContent
        property bool expanded: false

        BlurContainer {
            anchors.fill: parent
            radius: notifContent.expanded ? 16 : height / 2
            hovered: notifContent.expanded
            backgroundIsDark: root.isDark
            externalTextColor: root.textColor
            externalSubtleColor: root.subtleColor
            externalIconColor: root.iconColor
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
        }

        // Collapsed: bell icon + count badge
        Item {
            anchors.fill: parent
            visible: !notifContent.expanded
            opacity: notifContent.expanded ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: Icons.bell
                    font.family: Icons.font
                    font.pixelSize: 20
                    color: root.iconColor
                }

                Rectangle {
                    width: 20; height: 16; radius: 8
                    color: root.isDark ? Qt.rgba(1,1,1,0.2) : Qt.rgba(0,0,0,0.15)
                    visible: (Notifications.list?.length ?? 0) > 0

                    Text {
                        anchors.centerIn: parent
                        text: Notifications.list?.length ?? 0
                        color: root.textColor
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }
            }
        }

        // Expanded: full notification list with header
        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            visible: notifContent.expanded
            opacity: notifContent.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            // Header row: title, DND pill, clear-all
            RowLayout {
                width: parent.width

                Text {
                    text: Icons.bell
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: root.iconColor
                }
                Text {
                    Layout.fillWidth: true
                    text: "Notifications"
                    color: root.textColor
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                // DND toggle pill
                Rectangle {
                    width: dndRow.implicitWidth + 12
                    height: 22
                    radius: 11
                    color: Notifications.doNotDisturb
                           ? (root.isDark ? Qt.rgba(1,1,1,0.15) : Qt.rgba(0,0,0,0.1))
                           : (dndMouse.containsMouse ? (root.isDark ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.04)) : "transparent")
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: dndRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: Notifications.doNotDisturb ? Icons.bellSlash : Icons.bell
                            font.family: Icons.font
                            font.pixelSize: 11
                            color: Notifications.doNotDisturb ? root.textColor : root.subtleColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "DND"
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            color: Notifications.doNotDisturb ? root.textColor : root.subtleColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: dndMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.doNotDisturb = !Notifications.doNotDisturb
                    }
                }

                // Clear all
                Text {
                    text: Icons.trash
                    font.family: Icons.font
                    font.pixelSize: 14
                    color: clearMouse.containsMouse ? root.textColor : root.subtleColor
                    visible: (Notifications.list?.length ?? 0) > 0
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent; anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.discardAllNotifications()
                    }
                }
            }

            // Scrollable notification list
            Flickable {
                width: parent.width
                height: parent.height - 30
                clip: true
                contentHeight: notifCol.height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: notifCol
                    width: parent.width
                    spacing: 6

                    // Empty state
                    Column {
                        width: parent.width
                        visible: (Notifications.list?.length ?? 0) === 0
                        spacing: 8
                        topPadding: 40

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Icons.bellSlash
                            font.family: Icons.font
                            font.pixelSize: 28
                            color: root.subtleColor
                            opacity: 0.5
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No notifications"
                            color: root.subtleColor
                            font.pixelSize: 12
                        }
                    }

                    // Notification items
                    Repeater {
                        model: (Notifications.list ?? []).slice().sort((a, b) => b.time - a.time)

                        Item {
                            width: notifCol.width
                            height: notifRow.implicitHeight + 16

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: notifItemMouse.containsMouse
                                       ? (root.isDark ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.04))
                                       : "transparent"
                            }

                            RowLayout {
                                id: notifRow
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                // App icon
                                Item {
                                    width: 26; height: 26

                                    Image {
                                        id: nIcon
                                        anchors.fill: parent
                                        source: modelData?.appIcon ? "image://icon/" + modelData.appIcon : ""
                                        fillMode: Image.PreserveAspectFit
                                        visible: status === Image.Ready
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.bell
                                        font.family: Icons.font
                                        font.pixelSize: 13
                                        color: root.subtleColor
                                        visible: !nIcon.visible
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        width: parent.width
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData?.summary ?? "Notification"
                                            color: root.textColor
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: modelData ? NotificationUtils.getFriendlyNotifTimeString(modelData.time) : ""
                                            color: root.subtleColor
                                            font.pixelSize: 9
                                        }
                                    }

                                    Text {
                                        text: modelData?.appName ?? ""
                                        color: root.subtleColor
                                        font.pixelSize: 9
                                        visible: text !== ""
                                    }

                                    Text {
                                        text: modelData ? NotificationUtils.processNotificationBody(modelData.body, modelData.appName) : ""
                                        color: root.subtleColor
                                        font.pixelSize: 10
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                }

                                // Dismiss button
                                Text {
                                    text: Icons.cancel
                                    font.family: Icons.font
                                    font.pixelSize: 12
                                    color: dismissMouse.containsMouse ? root.textColor : root.subtleColor
                                    Layout.alignment: Qt.AlignTop
                                    MouseArea {
                                        id: dismissMouse
                                        anchors.fill: parent; anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Notifications.discardNotification(modelData.id)
                                    }
                                }
                            }

                            MouseArea {
                                id: notifItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                propagateComposedEvents: true
                                onPressed: (mouse) => mouse.accepted = false
                            }
                        }
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════
    // BUBBLE & TRANSFORM BUBBLE
    // ═════════════════════════════════════════════════════════════════

    component Bubble: Item {
        id: bubble
        default property alias content: visual.data

        property string itemId: ""
        property real itemX: 0
        property real itemY: 0
        property real itemWidth: 70
        property real itemHeight: 70
        property int animIndex: 0

        readonly property bool isFocused: bubbleContainer.focusedItemId === itemId
        readonly property bool isUnfocused: bubbleContainer.focusedItemId !== "" && !isFocused

        width: itemWidth;  height: itemHeight
        x: itemX - itemWidth / 2
        y: itemY - itemHeight / 2

        Component.onCompleted: bubbleContainer.registerItem(itemId, itemX, itemY, itemWidth, itemHeight)
        Component.onDestruction: bubbleContainer.unregisterItem(itemId)

        readonly property real targetScale: isFocused ? 1.15 : (isUnfocused ? 0.75 : 1.0)
        property real hoverScale: 1.0
        Behavior on hoverScale {
            NumberAnimation {
                duration: bubble.isFocused ? 150 : 350
                easing.type: bubble.isFocused ? Easing.OutBack : Easing.InOutCubic
                easing.overshoot: bubble.isFocused ? 1.2 : 1.0
            }
        }
        onTargetScaleChanged: hoverScale = targetScale

        z: isFocused ? 100 : (isUnfocused ? 1 : 10)

        property real floatY: 0
        SequentialAnimation on floatY {
            running: root.show && !bubble.isFocused
            loops: Animation.Infinite
            NumberAnimation { to: 3;  duration: 2000 + bubble.animIndex * 200; easing.type: Easing.InOutSine }
            NumberAnimation { to: -3; duration: 2000 + bubble.animIndex * 200; easing.type: Easing.InOutSine }
        }

        property real animProgress: root.show ? 1 : 0
        Behavior on animProgress {
            NumberAnimation {
                duration: root.animDuration + bubble.animIndex * 40
                easing.type: Easing.OutBack; easing.overshoot: 1.5
            }
        }

        Item {
            id: visual
            width: bubble.itemWidth;  height: bubble.itemHeight
            y: bubble.floatY

            transform: [
                Translate {
                    x: (root.originX - bubble.x - bubble.itemWidth / 2) * (1 - bubble.animProgress)
                    y: (root.originY - bubble.y - bubble.itemHeight / 2) * (1 - bubble.animProgress)
                },
                Scale {
                    origin.x: bubble.itemWidth / 2
                    origin.y: bubble.itemHeight
                    xScale: bubble.animProgress * bubble.hoverScale
                    yScale: bubble.animProgress * bubble.hoverScale
                }
            ]

            opacity: bubble.animProgress * (bubble.isUnfocused ? 0.25 : 1.0)
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    component TransformBubble: Item {
        id: tbubble
        default property alias content: tvisual.data

        property string itemId: ""
        property real itemX: 0
        property real itemY: 0
        property real itemWidth: 70
        property real itemHeight: 70
        property int animIndex: 0
        property real expandedWidth: itemWidth
        property real expandedHeight: itemHeight

        // Per-instance expansion center
        property real expandCenterX: root.implicitWidth / 2
        property real expandCenterY: root.implicitHeight / 2

        readonly property bool isFocused: bubbleContainer.focusedItemId === itemId
        readonly property bool isUnfocused: bubbleContainer.focusedItemId !== "" && !isFocused

        width: itemWidth;  height: itemHeight
        x: itemX - itemWidth / 2
        y: itemY - itemHeight / 2

        Component.onCompleted: bubbleContainer.registerItem(itemId, itemX, itemY, itemWidth, itemHeight)
        Component.onDestruction: bubbleContainer.unregisterItem(itemId)

        onIsFocusedChanged: {
            if (isFocused) bubbleContainer.setBlockZone(expandCenterX, expandCenterY, expandedWidth, expandedHeight)
            else bubbleContainer.clearBlockZone()
        }

        property real visualX: isFocused ? (expandCenterX - itemX) : 0
        property real visualY: isFocused ? (expandCenterY - itemY) : 0
        Behavior on visualX { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
        Behavior on visualY { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }

        property real displayWidth:  isFocused ? expandedWidth  : itemWidth
        property real displayHeight: isFocused ? expandedHeight : itemHeight
        Behavior on displayWidth  { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
        Behavior on displayHeight { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }

        readonly property real targetScale: isUnfocused ? 0.75 : 1.0
        property real hoverScale: 1.0
        Behavior on hoverScale { NumberAnimation { duration: 350; easing.type: Easing.InOutCubic } }
        onTargetScaleChanged: hoverScale = targetScale

        z: isFocused ? 100 : (isUnfocused ? 1 : 10)

        property real floatY: 0
        SequentialAnimation on floatY {
            running: root.show && !tbubble.isFocused
            loops: Animation.Infinite
            NumberAnimation { to: 3;  duration: 2000 + tbubble.animIndex * 200; easing.type: Easing.InOutSine }
            NumberAnimation { to: -3; duration: 2000 + tbubble.animIndex * 200; easing.type: Easing.InOutSine }
        }

        property real animProgress: root.show ? 1 : 0
        Behavior on animProgress {
            NumberAnimation {
                duration: root.animDuration + tbubble.animIndex * 40
                easing.type: Easing.OutBack; easing.overshoot: 1.5
            }
        }

        Item {
            id: tvisual
            width: tbubble.displayWidth
            height: tbubble.displayHeight
            x: tbubble.visualX
            y: tbubble.visualY + tbubble.floatY

            transform: [
                Translate {
                    x: (root.originX - tbubble.x - tbubble.itemWidth / 2) * (1 - tbubble.animProgress)
                    y: (root.originY - tbubble.y - tbubble.itemHeight / 2) * (1 - tbubble.animProgress)
                },
                Scale {
                    origin.x: tbubble.itemWidth / 2
                    origin.y: tbubble.itemHeight
                    xScale: tbubble.animProgress * tbubble.hoverScale
                    yScale: tbubble.animProgress * tbubble.hoverScale
                }
            ]

            opacity: tbubble.animProgress * (tbubble.isUnfocused ? 0.25 : 1.0)
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }
}
