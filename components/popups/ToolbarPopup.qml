import QtQuick
import QtQuick.Layouts
import "../../globals"
import "../../services"
import "../effects"
import "../containers"

/**
 * ToolbarPopup - Bubble layout with two item types:
 *   Bubble       – scales up on hover, others shrink
 *   TransformBubble – moves to center and expands on hover
 *
 * The BubbleContainer decides the state of every item:
 *   "normal", "focused", or "unfocused"
 */
Item {
    id: root

    property bool show: false
    property int animDuration: State.animDuration ?? 300

    signal closeRequested()

    implicitWidth: 600
    implicitHeight: 420
    width: implicitWidth
    height: implicitHeight

    readonly property real originX: implicitWidth
    readonly property real originY: implicitHeight

    property int screenX: 0
    property int screenY: 0

    // ── Data ──────────────────────────────────────────────────────
    readonly property var toggleBubbles: [
        { icon: Icons.wifiHigh,   prop: "wifiEnabled",      x: 170, y: 130, size: 80 },
        { icon: Icons.bluetooth,  prop: "bluetoothEnabled",  x: 290, y: 80,  size: 80 },
        { icon: Icons.caffeine,   prop: "caffeineMode",      x: 410, y: 80,  size: 80 },
        { icon: Icons.gamepad,    prop: "gameMode",          x: 530, y: 130, size: 80 }
    ]

    readonly property var toolBubbles: [
        { icon: Icons.regionScreenshot, action: "screenshot", x: 160, y: 250, size: 70 },
        { icon: Icons.recordScreen,     action: "record",     x: 170, y: 360, size: 70 },
        { icon: Icons.picker,           action: "color",      x: 550, y: 250, size: 70 },
        { icon: Icons.textT,            action: "ocr",        x: 540, y: 360, size: 70 }
    ]

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

        // ── Toggle bubbles ────────────────────────────────────────
        Repeater {
            model: root.toggleBubbles
            delegate: Bubble {
                required property var modelData
                required property int index
                itemId: "toggle_" + index
                itemX: modelData?.x ?? 0;  itemY: modelData?.y ?? 0
                itemWidth: modelData?.size ?? 70;  itemHeight: modelData?.size ?? 70
                animIndex: index

                BubbleContent {
                    anchors.fill: parent
                    focused: parent.isFocused
                    icon: modelData.icon
                    active: getToggleState(modelData.prop)
                    floatOffset: parent.floatY
                    onClicked: toggleProperty(modelData.prop)
                }
            }
        }

        // ── Tool bubbles ──────────────────────────────────────────
        Repeater {
            model: root.toolBubbles
            delegate: Bubble {
                required property var modelData
                required property int index
                itemId: "tool_" + index
                itemX: modelData?.x ?? 0;  itemY: modelData?.y ?? 0
                itemWidth: modelData?.size ?? 70;  itemHeight: modelData?.size ?? 70
                animIndex: index + 4

                BubbleContent {
                    anchors.fill: parent
                    focused: parent.isFocused
                    icon: modelData.icon
                    active: false
                    floatOffset: parent.floatY
                    onClicked: {
                        root.closeRequested()
                        Qt.callLater(() => executeAction(modelData.action))
                    }
                }
            }
        }

        // ── Volume slider ─────────────────────────────────────────
        Bubble {
            itemId: "volume"
            itemX: (root.implicitWidth + 190) / 2;  itemY: 185
            itemWidth: 250;  itemHeight: 60
            animIndex: 8

            SliderContent {
                anchors.fill: parent
                focused: parent.isFocused
                icon: Icons.volumeIcon(Audio.volume ?? 0, Audio.muted ?? false)
                label: "Volume";  value: Audio.volume ?? 0;  muted: Audio.muted ?? false
                onToggleMute: Audio.toggleMute()
                onSliderMoved: (val) => Audio.setVolume(val)
            }
        }

        // ── Brightness slider ─────────────────────────────────────
        Bubble {
            itemId: "brightness"
            itemX: (root.implicitWidth + 190) / 2;  itemY: 280
            itemWidth: 250;  itemHeight: 60
            animIndex: 9

            SliderContent {
                anchors.fill: parent
                focused: parent.isFocused
                icon: Icons.sun
                label: "Brightness";  value: Brightness.brightness ?? 0;  muted: false
                onSliderMoved: (val) => Brightness.setBrightness(Math.max(0.05, val))
            }
        }

        // ── Output picker (transforms to center) ─────────────────
        TransformBubble {
            id: outputItem
            itemId: "output"
            itemX: root.implicitWidth / 2 + 32;  itemY: 360
            itemWidth: 114;  itemHeight: 50
            animIndex: 10
            expandedWidth: 280
            expandedHeight: 50 + outputPicker.expandedHeight

            PickerContent {
                id: outputPicker
                anchors.fill: parent
                expanded: outputItem.isFocused
                icon: Icons.speakerHigh;  label: "Output"
                currentDevice: Audio.sink
                deviceList: Audio.outputDevices
                onDeviceSelected: (device) => Audio.setDefaultSink(device)
            }
        }

        // ── Input picker (transforms to center) ──────────────────
        TransformBubble {
            id: inputItem
            itemId: "input"
            itemX: root.implicitWidth / 2 + 168;  itemY: 360
            itemWidth: 114;  itemHeight: 50
            animIndex: 11
            expandedWidth: 280
            expandedHeight: 50 + inputPicker.expandedHeight

            PickerContent {
                id: inputPicker
                anchors.fill: parent
                expanded: inputItem.isFocused
                icon: Icons.mic;  label: "Input"
                currentDevice: Audio.source
                deviceList: Audio.inputDevices
                onDeviceSelected: (device) => Audio.setDefaultSource(device)
            }
        }
    }

    // ── Expose colors ─────────────────────────────────────────────
    readonly property bool isDark: bubbleContainer.isDark
    readonly property color textColor: bubbleContainer.textColor
    readonly property color subtleColor: bubbleContainer.subtleColor
    readonly property color iconColor: bubbleContainer.iconColor

    // ── Helpers ───────────────────────────────────────────────────
    function getToggleState(prop) {
        switch (prop) {
            case "wifiEnabled":      return Network.wifiEnabled ?? false
            case "bluetoothEnabled": return Bluetooth.enabled ?? false
            case "caffeineMode":     return Caffeine.enabled ?? false
            case "gameMode":         return State.gameMode ?? false
            default: return false
        }
    }

    function toggleProperty(prop) {
        switch (prop) {
            case "wifiEnabled":      Network.toggleWifi(); break
            case "bluetoothEnabled": Bluetooth.toggle(); break
            case "caffeineMode":     Caffeine.toggle(); break
            case "gameMode":         State.gameMode = !State.gameMode; break
        }
    }

    function executeAction(action) {
        switch (action) {
            case "screenshot": Screenshot.capture("area"); break
            case "record":     Screenshot.startRecording(); break
            case "color":      Screenshot.pickColor(); break
            case "ocr":        Screenshot.captureOCR(); break
        }
    }

    // ═════════════════════════════════════════════════════════════════
    // BUBBLE (simple) – scales up when focused, shrinks when unfocused
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

        // State from container
        readonly property bool isFocused: bubbleContainer.focusedItemId === itemId
        readonly property bool isUnfocused: bubbleContainer.focusedItemId !== "" && !isFocused

        // Layout (fixed, never moves)
        width: itemWidth
        height: itemHeight
        x: itemX - itemWidth / 2
        y: itemY - itemHeight / 2

        // Register bounds with container for centralized hit-testing
        Component.onCompleted: bubbleContainer.registerItem(itemId, itemX, itemY, itemWidth, itemHeight)
        Component.onDestruction: bubbleContainer.unregisterItem(itemId)

        // Scale: focused → bigger, unfocused → smaller
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

        // Float
        property real floatY: 0
        SequentialAnimation on floatY {
            running: root.show && !bubble.isFocused
            loops: Animation.Infinite
            NumberAnimation { to: 3;  duration: 2000 + bubble.animIndex * 200; easing.type: Easing.InOutSine }
            NumberAnimation { to: -3; duration: 2000 + bubble.animIndex * 200; easing.type: Easing.InOutSine }
        }

        // Slide-in progress
        property real animProgress: root.show ? 1 : 0
        Behavior on animProgress {
            NumberAnimation {
                duration: root.animDuration + bubble.animIndex * 40
                easing.type: Easing.OutBack; easing.overshoot: 1.5
            }
        }

        // Visual wrapper
        Item {
            id: visual
            width: bubble.itemWidth
            height: bubble.itemHeight
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

    // ═════════════════════════════════════════════════════════════════
    // TRANSFORM BUBBLE – moves to center & expands when focused
    // ═════════════════════════════════════════════════════════════════
    component TransformBubble: Item {
        id: tbubble
        default property alias content: tvisual.data

        property string itemId: ""
        property real itemX: 0
        property real itemY: 0
        property real itemWidth: 70
        property real itemHeight: 70
        property int animIndex: 0

        // Expanded dimensions
        property real expandedWidth: itemWidth
        property real expandedHeight: itemHeight

        // State from container
        readonly property bool isFocused: bubbleContainer.focusedItemId === itemId
        readonly property bool isUnfocused: bubbleContainer.focusedItemId !== "" && !isFocused

        // Center target
        readonly property real centerX: (root.implicitWidth + 190) / 2
        readonly property real centerY: root.implicitHeight / 2

        // Layout (fixed, never moves – hover area stays here)
        width: itemWidth
        height: itemHeight
        x: itemX - itemWidth / 2
        y: itemY - itemHeight / 2

        // Register bounds with container for centralized hit-testing
        Component.onCompleted: bubbleContainer.registerItem(itemId, itemX, itemY, itemWidth, itemHeight)
        Component.onDestruction: bubbleContainer.unregisterItem(itemId)

        // When focused, set block zone so items underneath can't steal focus
        onIsFocusedChanged: {
            if (isFocused) {
                bubbleContainer.setBlockZone(centerX, centerY, expandedWidth, expandedHeight)
            } else {
                bubbleContainer.clearBlockZone()
            }
        }

        // Animated offset to center
        property real visualX: isFocused ? (centerX - itemX) : 0
        property real visualY: isFocused ? (centerY - itemY) : 0
        Behavior on visualX { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
        Behavior on visualY { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }

        // Animated size
        property real displayWidth:  isFocused ? expandedWidth  : itemWidth
        property real displayHeight: isFocused ? expandedHeight : itemHeight
        Behavior on displayWidth  { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
        Behavior on displayHeight { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }

        // Scale (no grow on focus for transforms, just shrink when unfocused)
        readonly property real targetScale: isUnfocused ? 0.75 : 1.0
        property real hoverScale: 1.0
        Behavior on hoverScale {
            NumberAnimation { duration: 350; easing.type: Easing.InOutCubic }
        }
        onTargetScaleChanged: hoverScale = targetScale

        z: isFocused ? 100 : (isUnfocused ? 1 : 10)

        // Float
        property real floatY: 0
        SequentialAnimation on floatY {
            running: root.show && !tbubble.isFocused
            loops: Animation.Infinite
            NumberAnimation { to: 3;  duration: 2000 + tbubble.animIndex * 200; easing.type: Easing.InOutSine }
            NumberAnimation { to: -3; duration: 2000 + tbubble.animIndex * 200; easing.type: Easing.InOutSine }
        }

        // Slide-in progress
        property real animProgress: root.show ? 1 : 0
        Behavior on animProgress {
            NumberAnimation {
                duration: root.animDuration + tbubble.animIndex * 40
                easing.type: Easing.OutBack; easing.overshoot: 1.5
            }
        }

        // Visual wrapper – moves to center, expands
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

    // ═════════════════════════════════════════════════════════════════
    // CONTENT COMPONENTS (visuals only, no hover logic)
    // ═════════════════════════════════════════════════════════════════

    // ── BubbleContent (icon button) ──────────────────────────────
    component BubbleContent: Item {
        id: bubbleContent
        property string icon: ""
        property bool active: false
        property bool focused: false
        property real floatOffset: 0
        signal clicked()

        BlurContainer {
            anchors.fill: parent
            radius: width / 2
            highlightActive: bubbleContent.active
            hovered: bubbleContent.focused
            backgroundIsDark: root.isDark
            externalTextColor: root.textColor
            externalSubtleColor: root.subtleColor
            externalIconColor: root.iconColor
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -floatOffset * 0.3
            text: bubbleContent.icon
            font.family: Icons.font
            font.pixelSize: parent.width * 0.38
            color: active ? root.textColor : root.subtleColor
        }

        MouseArea {
            id: bubbleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bubbleContent.clicked()
        }
    }

    // ── SliderContent ────────────────────────────────────────────
    component SliderContent: Item {
        id: sliderContent
        property string icon: ""
        property string label: ""
        property real value: 0
        property bool muted: false
        property bool focused: false
        signal toggleMute()
        signal sliderMoved(real val)

        BlurContainer {
            anchors.fill: parent
            radius: height / 2
            hovered: sliderContent.focused
            backgroundIsDark: root.isDark
            externalTextColor: root.textColor
            externalSubtleColor: root.subtleColor
            externalIconColor: root.iconColor
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14;  anchors.rightMargin: 14
            spacing: 10

            Text {
                text: sliderContent.icon
                font.family: Icons.font; font.pixelSize: 16
                color: muted ? root.subtleColor : root.iconColor
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sliderContent.toggleMute()
                }
            }

            Item {
                Layout.fillWidth: true; height: 20

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 5; radius: 2.5
                    color: root.isDark ? Qt.rgba(1,1,1,0.2) : Qt.rgba(0,0,0,0.1)

                    Rectangle {
                        width: parent.width * sliderContent.value
                        height: parent.height; radius: 2.5
                        color: muted ? root.subtleColor : root.textColor
                    }
                }

                Rectangle {
                    x: Math.max(0, Math.min(parent.width - 14, parent.width * sliderContent.value - 7))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; radius: 7
                    color: root.textColor
                }

                MouseArea {
                    id: sliderArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (mouse) => sliderContent.sliderMoved(Math.max(0, Math.min(1, mouse.x / width)))
                    onPositionChanged: (mouse) => { if (pressed) sliderContent.sliderMoved(Math.max(0, Math.min(1, mouse.x / width))) }
                }
            }

            Text {
                text: Math.round(sliderContent.value * 100) + "%"
                color: root.subtleColor
                font.pixelSize: 10; font.family: "monospace"
                Layout.preferredWidth: 32
            }
        }
    }

    // ── PickerContent ────────────────────────────────────────────
    component PickerContent: Item {
        id: pickerContent
        property string icon: ""
        property string label: ""
        property var currentDevice: null
        property var deviceList: []
        property bool expanded: false
        property real expandedHeight: deviceCol.height
        signal deviceSelected(var device)

        BlurContainer {
            anchors.fill: parent
            radius: pickerContent.expanded ? 12 : 25
            hovered: pickerContent.expanded
            backgroundIsDark: root.isDark
            externalTextColor: root.textColor
            externalSubtleColor: root.subtleColor
            externalIconColor: root.iconColor
            Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
        }

        Column {
            anchors.fill: parent

            Item {
                width: parent.width; height: 50
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: pickerContent.icon
                        font.family: Icons.font; font.pixelSize: 16
                        color: root.iconColor
                    }

                    Column {
                        Layout.fillWidth: true; spacing: 1
                        Text {
                            text: pickerContent.label
                            color: root.subtleColor; font.pixelSize: 9
                        }
                        Text {
                            text: Audio.friendlyDeviceName && pickerContent.currentDevice
                                  ? Audio.friendlyDeviceName(pickerContent.currentDevice) : "..."
                            color: root.textColor
                            font.pixelSize: 10; font.weight: Font.Medium
                            elide: Text.ElideRight; width: parent.width
                        }
                    }

                    Text {
                        text: pickerContent.expanded ? Icons.caretUp : Icons.caretDown
                        font.family: Icons.font; font.pixelSize: 12
                        color: root.subtleColor
                    }
                }
            }

            Column {
                id: deviceCol
                width: parent.width
                visible: pickerContent.expanded

                Repeater {
                    model: pickerContent.deviceList
                    delegate: Item {
                        width: deviceCol.width; height: 36
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 4; radius: 8
                            color: deviceMouse.containsMouse
                                   ? (root.isDark ? Qt.rgba(1,1,1,0.1) : Qt.rgba(0,0,0,0.05))
                                   : "transparent"
                        }
                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: Audio.friendlyDeviceName ? Audio.friendlyDeviceName(modelData) : "..."
                            color: pickerContent.currentDevice === modelData ? root.textColor : root.subtleColor
                            font.pixelSize: 11
                            font.weight: pickerContent.currentDevice === modelData ? Font.Medium : Font.Normal
                            elide: Text.ElideRight; width: parent.width - 24
                        }
                        MouseArea {
                            id: deviceMouse
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pickerContent.deviceSelected(modelData)
                        }
                    }
                }
            }
        }

        MouseArea {
            id: pickerMouse
            anchors.fill: parent; hoverEnabled: true
            propagateComposedEvents: true
            onPressed: (mouse) => mouse.accepted = false
        }
    }
}
