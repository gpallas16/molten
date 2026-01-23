import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../globals"
import "../services"
import "../components/effects"

Item {
    id: root
    implicitWidth: 350
    implicitHeight: contentColumn.implicitHeight + 32

    signal closeRequested()

    // Adaptive colors based on background
    AdaptiveColors {
        id: adaptiveColors
        region: "notch"
    }

    // Helper functions for toggle states
    function getToggleState(prop) {
        switch(prop) {
            case "wifiEnabled": return Network.wifiEnabled ?? false
            case "bluetoothEnabled": return Bluetooth.enabled ?? false
            case "caffeineMode": return Caffeine.enabled ?? false
            case "gameMode": return State.gameMode ?? false
            default: return false
        }
    }
    
    function toggleProperty(prop) {
        switch(prop) {
            case "wifiEnabled": 
                Network.toggleWifi()
                break
            case "bluetoothEnabled": 
                Bluetooth.toggle()
                break
            case "caffeineMode": 
                Caffeine.toggle()
                break
            case "gameMode": 
                State.gameMode = !State.gameMode
                break
        }
    }

    Column {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ═══════════════════════════════════════════════════════════════
        // QUICK TOGGLES
        // ═══════════════════════════════════════════════════════════════
        GridLayout {
            width: parent.width
            columns: 4
            rowSpacing: 12
            columnSpacing: 12

            Repeater {
                model: [
                    { icon: "📶", label: "WiFi", prop: "wifiEnabled" },
                    { icon: "🔷", label: "Bluetooth", prop: "bluetoothEnabled" },
                    { icon: "☕", label: "Caffeine", prop: "caffeineMode" },
                    { icon: "🎮", label: "Game Mode", prop: "gameMode" }
                ]

                delegate: Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    
                    property bool isEnabled: root.getToggleState(modelData.prop)

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: isEnabled ? adaptiveColors.textColor : "transparent"
                        opacity: isEnabled ? 0.15 : 0.08
                        border.width: 1
                        border.color: adaptiveColors.textColor
                        
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }

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
                            color: isEnabled ? adaptiveColors.textColor : adaptiveColors.subtleTextColor
                            font.pixelSize: 10
                            font.weight: isEnabled ? Font.DemiBold : Font.Normal
                            anchors.horizontalCenter: parent.horizontalCenter
                            
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleProperty(modelData.prop)
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // BRIGHTNESS SLIDER (Using Brightness Service)
        // ═══════════════════════════════════════════════════════════════
        Column {
            width: parent.width
            spacing: 10

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
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }
                Text {
                    text: Math.round(Brightness.brightness * 100) + "%"
                    color: adaptiveColors.subtleTextColor
                    font.pixelSize: 12
                    font.family: "monospace"
                }
            }

            // Custom slider
            Item {
                width: parent.width
                height: 24

                // Background track
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 8
                    radius: 4
                    color: adaptiveColors.subtleTextColor
                    opacity: 0.2
                }

                // Progress fill
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * Brightness.brightness
                    height: 8
                    radius: 4
                    color: adaptiveColors.textColor
                    
                    Behavior on width {
                        NumberAnimation { duration: 50 }
                    }
                }

                // Handle
                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width, parent.width * Brightness.brightness - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 10
                    color: adaptiveColors.textColor
                    
                    Behavior on x {
                        NumberAnimation { duration: 50 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    
                    onPressed: (mouse) => updateBrightness(mouse)
                    onPositionChanged: (mouse) => {
                        if (pressed) updateBrightness(mouse)
                    }
                    
                    function updateBrightness(mouse) {
                        var newVal = Math.max(0.05, Math.min(1, (mouse.x + 4) / (width - 8)))
                        Brightness.setBrightness(newVal)
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // VOLUME SLIDER (Using Audio Service)
        // ═══════════════════════════════════════════════════════════════
        Column {
            width: parent.width
            spacing: 10

            RowLayout {
                width: parent.width

                Text {
                    id: volumeIconText
                    text: {
                        if (Audio.muted || Audio.volume === 0) return "🔇"
                        if (Audio.volume < 0.33) return "🔉"
                        if (Audio.volume < 0.66) return "🔊"
                        return "🔊"
                    }
                    font.pixelSize: 16
                    
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.toggleMute()
                    }
                }
                Text {
                    text: "Volume"
                    color: adaptiveColors.textColor
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }
                Text {
                    text: Math.round(Audio.volume * 100) + "%"
                    color: adaptiveColors.subtleTextColor
                    font.pixelSize: 12
                    font.family: "monospace"
                }
            }

            // Custom slider
            Item {
                width: parent.width
                height: 24

                // Background track
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 8
                    radius: 4
                    color: adaptiveColors.subtleTextColor
                    opacity: 0.2
                }

                // Progress fill
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * Audio.volume
                    height: 8
                    radius: 4
                    color: Audio.muted ? adaptiveColors.subtleTextColor : adaptiveColors.textColor
                    
                    Behavior on width {
                        NumberAnimation { duration: 50 }
                    }
                }

                // Handle
                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width, parent.width * Audio.volume - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 10
                    color: adaptiveColors.textColor
                    
                    Behavior on x {
                        NumberAnimation { duration: 50 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    
                    onPressed: (mouse) => updateVolume(mouse)
                    onPositionChanged: (mouse) => {
                        if (pressed) updateVolume(mouse)
                    }
                    
                    // Scroll wheel support
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) {
                            Audio.incrementVolume()
                        } else {
                            Audio.decrementVolume()
                        }
                    }
                    
                    function updateVolume(mouse) {
                        var newVal = Math.max(0, Math.min(1, (mouse.x + 4) / (width - 8)))
                        Audio.setVolume(newVal)
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // MICROPHONE VOLUME SLIDER (Using Audio Service)
        // ═══════════════════════════════════════════════════════════════
        Column {
            width: parent.width
            spacing: 10

            RowLayout {
                width: parent.width

                Text {
                    id: micIconText
                    text: Audio.micMuted ? "🎤❌" : "🎤"
                    font.pixelSize: 16
                    
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.toggleMicMute()
                    }
                }
                Text {
                    text: "Microphone"
                    color: adaptiveColors.textColor
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }
                Text {
                    text: Math.round(Audio.micVolume * 100) + "%"
                    color: adaptiveColors.subtleTextColor
                    font.pixelSize: 12
                    font.family: "monospace"
                }
            }

            // Custom slider
            Item {
                width: parent.width
                height: 24

                // Background track
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 8
                    radius: 4
                    color: adaptiveColors.subtleTextColor
                    opacity: 0.2
                }

                // Progress fill
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * Audio.micVolume
                    height: 8
                    radius: 4
                    color: Audio.micMuted ? adaptiveColors.subtleTextColor : adaptiveColors.textColor
                    
                    Behavior on width {
                        NumberAnimation { duration: 50 }
                    }
                }

                // Handle
                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width, parent.width * Audio.micVolume - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 10
                    color: adaptiveColors.textColor
                    
                    Behavior on x {
                        NumberAnimation { duration: 50 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    
                    onPressed: (mouse) => updateMicVolume(mouse)
                    onPositionChanged: (mouse) => {
                        if (pressed) updateMicVolume(mouse)
                    }
                    
                    // Scroll wheel support
                    onWheel: (wheel) => {
                        var currentVol = Audio.micVolume
                        if (wheel.angleDelta.y > 0) {
                            Audio.setMicVolume(Math.min(1, currentVol + 0.05))
                        } else {
                            Audio.setMicVolume(Math.max(0, currentVol - 0.05))
                        }
                    }
                    
                    function updateMicVolume(mouse) {
                        var newVal = Math.max(0, Math.min(1, (mouse.x + 4) / (width - 8)))
                        Audio.setMicVolume(newVal)
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // QUICK TOOLS ROW
        // ═══════════════════════════════════════════════════════════════
        Row {
            width: parent.width
            spacing: 8
            
            // Screenshot
            ToolButton {
                icon: "📷"
                label: "Screenshot"
                onClicked: {
                    root.closeRequested()
                    Screenshot.capture("area")
                }
            }
            
            // Screen Record
            ToolButton {
                icon: "🔴"
                label: "Record"
                onClicked: {
                    root.closeRequested()
                    screenRecordDelayTimer.start()
                }
            }
            
            // Color Picker
            ToolButton {
                icon: "🎨"
                label: "Color"
                onClicked: {
                    root.closeRequested()
                    colorPickerDelayTimer.start()
                }
            }
            
            // OCR
            ToolButton {
                icon: "📝"
                label: "OCR"
                onClicked: {
                    root.closeRequested()
                    ocrDelayTimer.start()
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // OUTPUT DEVICE
        // ═══════════════════════════════════════════════════════════════
        Column {
            width: parent.width
            spacing: 0
            
            // Output device header (clickable to expand)
            Item {
                id: outputHeader
                width: parent.width
                height: 50
                
                property bool expanded: false
                
                Rectangle {
                    anchors.fill: parent
                    radius: outputHeader.expanded ? 0 : 10
                    topLeftRadius: 10
                    topRightRadius: 10
                    bottomLeftRadius: outputHeader.expanded ? 0 : 10
                    bottomRightRadius: outputHeader.expanded ? 0 : 10
                    color: adaptiveColors.textColor
                    opacity: outputMouse.containsMouse ? 0.1 : 0.06
                    
                    Behavior on opacity {
                        NumberAnimation { duration: 100 }
                    }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    z: 1

                    Text {
                        text: "🔈"
                        font.pixelSize: 16
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Output"
                            color: adaptiveColors.subtleTextColor
                            font.pixelSize: 10
                        }
                        Text {
                            text: Audio.friendlyDeviceName(Audio.sink)
                            color: adaptiveColors.textColor
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                    Text {
                        text: outputHeader.expanded ? "▲" : "▼"
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 10
                    }
                }
                
                MouseArea {
                    id: outputMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: outputHeader.expanded = !outputHeader.expanded
                }
            }
            
            // Output device list (expandable)
            Item {
                width: parent.width
                height: outputHeader.expanded ? outputDeviceList.implicitHeight : 0
                clip: true
                
                Behavior on height {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuart }
                }
                
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    topLeftRadius: 0
                    topRightRadius: 0
                    color: adaptiveColors.textColor
                    opacity: 0.04
                }
                
                Column {
                    id: outputDeviceList
                    width: parent.width
                    
                    Repeater {
                        model: Audio.outputDevices
                        
                        delegate: Item {
                            required property var modelData
                            width: parent.width
                            height: 44
                            
                            property bool isSelected: Audio.sink === modelData
                            
                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.topMargin: 2
                                anchors.bottomMargin: 2
                                radius: 8
                                color: adaptiveColors.textColor
                                opacity: outputDeviceMouse.containsMouse ? 0.1 : (isSelected ? 0.08 : 0)
                                
                                Behavior on opacity {
                                    NumberAnimation { duration: 100 }
                                }
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 10

                                Text {
                                    text: "🔊"
                                    font.pixelSize: 14
                                    opacity: isSelected ? 1 : 0.6
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: Audio.friendlyDeviceName(modelData)
                                    color: isSelected ? adaptiveColors.textColor : adaptiveColors.subtleTextColor
                                    font.pixelSize: 12
                                    font.weight: isSelected ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: "✓"
                                    color: adaptiveColors.textColor
                                    font.pixelSize: 14
                                    visible: isSelected
                                }
                            }
                            
                            MouseArea {
                                id: outputDeviceMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    Audio.setDefaultSink(modelData)
                                    outputHeader.expanded = false
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // INPUT DEVICE
        // ═══════════════════════════════════════════════════════════════
        Column {
            width: parent.width
            spacing: 0
            
            // Input device header (clickable to expand)
            Item {
                id: inputHeader
                width: parent.width
                height: 50
                
                property bool expanded: false
                
                Rectangle {
                    anchors.fill: parent
                    radius: inputHeader.expanded ? 0 : 10
                    topLeftRadius: 10
                    topRightRadius: 10
                    bottomLeftRadius: inputHeader.expanded ? 0 : 10
                    bottomRightRadius: inputHeader.expanded ? 0 : 10
                    color: adaptiveColors.textColor
                    opacity: inputMouse.containsMouse ? 0.1 : 0.06
                    
                    Behavior on opacity {
                        NumberAnimation { duration: 100 }
                    }
                }
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    z: 1

                    Text {
                        text: "🎤"
                        font.pixelSize: 16
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Input"
                            color: adaptiveColors.subtleTextColor
                            font.pixelSize: 10
                        }
                        Text {
                            text: Audio.friendlyDeviceName(Audio.source)
                            color: adaptiveColors.textColor
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                    Text {
                        text: inputHeader.expanded ? "▲" : "▼"
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 10
                    }
                }
                
                MouseArea {
                    id: inputMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: inputHeader.expanded = !inputHeader.expanded
                }
            }
            
            // Input device list (expandable)
            Item {
                width: parent.width
                height: inputHeader.expanded ? inputDeviceList.implicitHeight : 0
                clip: true
                
                Behavior on height {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuart }
                }
                
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    topLeftRadius: 0
                    topRightRadius: 0
                    color: adaptiveColors.textColor
                    opacity: 0.04
                }
                
                Column {
                    id: inputDeviceList
                    width: parent.width
                    
                    Repeater {
                        model: Audio.inputDevices
                        
                        delegate: Item {
                            required property var modelData
                            width: parent.width
                            height: 44
                            
                            property bool isSelected: Audio.source === modelData
                            
                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.topMargin: 2
                                anchors.bottomMargin: 2
                                radius: 8
                                color: adaptiveColors.textColor
                                opacity: inputDeviceMouse.containsMouse ? 0.1 : (isSelected ? 0.08 : 0)
                                
                                Behavior on opacity {
                                    NumberAnimation { duration: 100 }
                                }
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 10

                                Text {
                                    text: "🎙️"
                                    font.pixelSize: 14
                                    opacity: isSelected ? 1 : 0.6
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: Audio.friendlyDeviceName(modelData)
                                    color: isSelected ? adaptiveColors.textColor : adaptiveColors.subtleTextColor
                                    font.pixelSize: 12
                                    font.weight: isSelected ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: "✓"
                                    color: adaptiveColors.textColor
                                    font.pixelSize: 14
                                    visible: isSelected
                                }
                            }
                            
                            MouseArea {
                                id: inputDeviceMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    Audio.setDefaultSource(modelData)
                                    inputHeader.expanded = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // TOOL BUTTON COMPONENT
    // ═══════════════════════════════════════════════════════════════
    component ToolButton: Item {
        property string icon
        property string label
        signal clicked()
        
        width: (parent.width - 24) / 4
        height: 60
        
        Rectangle {
            anchors.fill: parent
            radius: 10
            color: adaptiveColors.textColor
            opacity: toolMouse.containsMouse ? 0.12 : 0.06
            
            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }
        }
        
        Column {
            anchors.centerIn: parent
            spacing: 4
            
            Text {
                text: icon
                font.pixelSize: 20
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: label
                color: adaptiveColors.textColor
                font.pixelSize: 10
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
        
        MouseArea {
            id: toolMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: parent.clicked()
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PROCESSES - Delay timers for tools that need UI to close first
    // ═══════════════════════════════════════════════════════════════
    
    Timer {
        id: screenRecordDelayTimer
        interval: 300
        onTriggered: Screenshot.startRecording()
    }
    
    Timer {
        id: colorPickerDelayTimer
        interval: 300
        onTriggered: Screenshot.pickColor()
    }
    
    Timer {
        id: ocrDelayTimer
        interval: 300
        onTriggered: Screenshot.captureOCR()
    }
}
