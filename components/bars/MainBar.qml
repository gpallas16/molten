import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../globals" as Root
import "../../globals"
import "../../services"
import "../effects"
import "../behavior"

// Exact Ambxst animation structure
Item {
    id: notchContainer

    property string currentView: "default"
    property bool isExpanded: currentView !== "default"
    property bool screenNotchOpen: isExpanded || volumeOverlayActive

    // Discrete mode: bar shrinks to a minimal notch showing only time and notification
    property bool discreteMode: false
    property bool discreteModeEnabled: true  // Master toggle for discrete mode behavior
    
    // Auto-hide state (controlled by parent) - slides bar down when hiding
    property bool showBar: true
    
    // ═══════════════════════════════════════════════════════════════
    // VOLUME OVERLAY - GNOME-style volume feedback
    // ═══════════════════════════════════════════════════════════════
    property bool volumeOverlayActive: false
    property bool wasDiscreteBeforeVolume: false  // Store previous discrete state
    property string previousBarState: ""  // Store previous bar state for shell
    
    // Signal to tell parent to switch to floating mode
    signal volumeOverlayStateChanged(bool active)
    
    // Function to show volume overlay (called externally when volume changes via scroll)
    function showVolumeOverlay() {
        if (!volumeOverlayActive) {
            wasDiscreteBeforeVolume = discreteMode
        }
        volumeOverlayActive = true
        volumeHideTimer.restart()
    }
    
    // Timer to hide volume overlay after 2 seconds of no activity
    Timer {
        id: volumeHideTimer
        interval: 2000
        onTriggered: {
            volumeOverlayActive = false
        }
    }
    
    // Emit state change signal when volume overlay state changes
    onVolumeOverlayActiveChanged: {
        volumeOverlayStateChanged(volumeOverlayActive)
    }
    
    // Y position for glass backdrop sync - use binding to always match transform
    property real yPosition: slideTransform.y
    
    // Slide animation: translate Y when hiding (like WorkspaceBar and StatusBar)
    transform: Translate {
        id: slideTransform
        y: showBar ? 0 : (notchContainer.implicitHeight + 20)
        
        Behavior on y {
            NumberAnimation {
                duration: 400
                easing.type: showBar ? Easing.OutBack : Easing.InQuad
                easing.overshoot: 1.2
            }
        }
    }
    
    // Signal for parent to detect hover on the bar
    signal barHoverChanged(bool hovering)
    signal closeRequested()

    // Ambxst uses 300ms
    property int animDuration: Root.State.animDuration
    
    // Discrete mode dimensions - wider to fit time + notification icon
    readonly property int discreteWidth: 110
    readonly property int discreteHeight: 24
    readonly property int normalHeight: 44
    // Volume overlay dimensions
    readonly property int volumeOverlayWidth: 280
    readonly property int volumeOverlayHeight: 44
    
    // Discrete mode uses flat bottom (attached to screen edge)
    property bool discreteFlatBottom: discreteMode && !screenNotchOpen && !volumeOverlayActive
    
    // Adaptive colors based on background
    AdaptiveColors {
        id: adaptiveColors
        region: "notch"
    }
    
    // Force animation retrigger on every view change
    property real animationTrigger: 0
    onScreenNotchOpenChanged: {
        if (screenNotchOpen) {
            animationTrigger = Math.random()
        }
    }

    // Helper function for creating fade animations
    function createFadeAnim(from, to) {
        return { property: "opacity", from: from, to: to, duration: animDuration, easing: Easing.OutQuart }
    }
    
    // Helper function for creating scale animations
    function createScaleAnim(from, to, useBack) {
        return { 
            property: "scale", from: from, to: to, duration: animDuration, 
            easing: useBack ? Easing.OutBack : Easing.OutQuart, overshoot: useBack ? 1.2 : 1.0 
        }
    }

    // CRITICAL: Ambxst animates implicitWidth/Height on the ROOT Item
    // In discrete mode, shrink to minimal notch; otherwise use normal sizes
    // Volume overlay takes priority over discrete mode
    implicitWidth: {
        if (volumeOverlayActive && currentView === "default") {
            return volumeOverlayWidth
        } else if (discreteMode && !screenNotchOpen) {
            return discreteWidth
        } else if (screenNotchOpen) {
            return Math.max(stackContainer.width + 32 + animationTrigger * 0, 290)
        } else {
            return stackContainer.width + 24
        }
    }
    implicitHeight: {
        if (volumeOverlayActive && currentView === "default") {
            return volumeOverlayHeight
        } else if (discreteMode && !screenNotchOpen) {
            return discreteHeight
        } else if (screenNotchOpen) {
            return Math.max(stackContainer.height + 32 + animationTrigger * 0, 44)
        } else {
            return normalHeight
        }
    }

    // Ambxst: Behavior on implicitWidth/Height with conditional easing
    Behavior on implicitWidth {
        enabled: (screenNotchOpen || stackViewInternal.busy || discreteMode !== undefined) && animDuration > 0
        NumberAnimation {
            duration: animDuration
            easing.type: screenNotchOpen ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: screenNotchOpen ? 1.8 : 1.0
        }
    }

    Behavior on implicitHeight {
        enabled: (screenNotchOpen || stackViewInternal.busy || discreteMode !== undefined) && animDuration > 0
        NumberAnimation {
            duration: animDuration
            easing.type: screenNotchOpen ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: screenNotchOpen ? 1.8 : 1.0
        }
    }

    ShadowBorder {
        // In discrete mode, use smaller roundness for the notch look
        radius: {
            if (discreteMode && !screenNotchOpen) {
                return 12  // Rounded top corners for notch
            } else if (screenNotchOpen) {
                return Theme.containerRoundness
            } else {
                return Theme.barRoundness
            }
        }
        
        // Flat bottom in discrete mode (attached to edge)
        flatBottom: discreteFlatBottom
        
        Behavior on radius {
            enabled: animDuration > 0
            NumberAnimation {
                duration: animDuration
                easing.type: screenNotchOpen ? Easing.OutBack : Easing.OutQuart
                easing.overshoot: screenNotchOpen ? 1.8 : 1.0
            }
        }
    }

    // Content container (Ambxst: stackContainer)
    Item {
        id: stackContainer
        anchors.centerIn: parent
        width: stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitWidth + (screenNotchOpen ? 32 : 0) : (screenNotchOpen ? 32 : 0)
        height: stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitHeight + (screenNotchOpen ? 32 : 0) : (screenNotchOpen ? 32 : 0)
        clip: true

        StackView {
            id: stackViewInternal
            anchors.fill: parent
            anchors.margins: screenNotchOpen ? 16 : 0
            initialItem: defaultViewComponent

            pushEnter: Transition {
                PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: animDuration; easing.type: Easing.OutQuart }
                PropertyAnimation { property: "scale"; from: 0.8; to: 1; duration: animDuration; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }

            pushExit: Transition {
                PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: animDuration; easing.type: Easing.OutQuart }
                PropertyAnimation { property: "scale"; from: 1; to: 1.05; duration: animDuration; easing.type: Easing.OutQuart }
            }

            popEnter: Transition {
                PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: animDuration; easing.type: Easing.OutQuart }
                PropertyAnimation { property: "scale"; from: 1.05; to: 1; duration: animDuration; easing.type: Easing.OutQuart }
            }

            popExit: Transition {
                PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: animDuration; easing.type: Easing.OutQuart }
                PropertyAnimation { property: "scale"; from: 1; to: 0.95; duration: animDuration; easing.type: Easing.OutQuart }
            }

            replaceEnter: Transition {
                PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: animDuration; easing.type: Easing.OutQuart }
                PropertyAnimation { property: "scale"; from: 0.8; to: 1; duration: animDuration; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }

            replaceExit: Transition {
                PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: animDuration; easing.type: Easing.OutQuart }
                PropertyAnimation { property: "scale"; from: 1; to: 1.05; duration: animDuration; easing.type: Easing.OutQuart }
            }
        }
    }

    // Default collapsed view
    Component {
        id: defaultViewComponent
        Item {
            implicitWidth: {
                if (volumeOverlayActive) return volumeOverlayRow.implicitWidth
                if (discreteMode) return discreteRow.implicitWidth
                return defaultRow.implicitWidth
            }
            implicitHeight: {
                if (volumeOverlayActive) return 36
                if (discreteMode) return 20
                return 36
            }

            // ═══════════════════════════════════════════════════════════════
            // VOLUME OVERLAY ROW - Shows when volume is being adjusted
            // ═══════════════════════════════════════════════════════════════
            RowLayout {
                id: volumeOverlayRow
                anchors.centerIn: parent
                spacing: 12
                visible: volumeOverlayActive
                opacity: volumeOverlayActive ? 1 : 0
                
                Behavior on opacity {
                    NumberAnimation { duration: animDuration / 2; easing.type: Easing.InOutQuad }
                }
                
                // Volume icon
                Text {
                    id: volumeIcon
                    text: {
                        if (Audio.muted || Audio.volume === 0) return "🔇"
                        if (Audio.volume < 0.33) return "🔉"
                        if (Audio.volume < 0.66) return "🔊"
                        return "🔊"
                    }
                    font.pixelSize: 18
                    Layout.alignment: Qt.AlignVCenter
                }
                
                // Volume slider bar
                Item {
                    Layout.preferredWidth: 180
                    Layout.preferredHeight: 8
                    Layout.alignment: Qt.AlignVCenter
                    
                    // Background track
                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: adaptiveColors.subtleTextColor
                        opacity: 0.3
                    }
                    
                    // Progress fill
                    Rectangle {
                        width: parent.width * Audio.volume
                        height: parent.height
                        radius: 4
                        color: adaptiveColors.textColor
                        
                        Behavior on width {
                            NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                        }
                    }
                    
                    // Make slider interactive
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onPressed: (mouse) => {
                            updateVolumeFromMouse(mouse)
                        }
                        
                        onPositionChanged: (mouse) => {
                            if (pressed) {
                                updateVolumeFromMouse(mouse)
                            }
                        }
                        
                        function updateVolumeFromMouse(mouse) {
                            var newVolume = Math.max(0, Math.min(1, (mouse.x - 8) / (width - 16)))
                            Audio.setVolume(newVolume)
                            volumeHideTimer.restart()
                        }
                        
                        // Scroll wheel support on the slider too
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y > 0) {
                                Audio.incrementVolume()
                            } else {
                                Audio.decrementVolume()
                            }
                            volumeHideTimer.restart()
                        }
                    }
                }
                
                // Volume percentage
                Text {
                    text: Math.round(Audio.volume * 100) + "%"
                    color: adaptiveColors.textColor
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.family: "monospace"
                    Layout.preferredWidth: 40
                    Layout.alignment: Qt.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Full default row (visible when not in discrete mode and not volume overlay)
            RowLayout {
                id: defaultRow
                anchors.centerIn: parent
                spacing: 10
                visible: !discreteMode && !volumeOverlayActive
                opacity: (discreteMode || volumeOverlayActive) ? 0 : 1
                
                Behavior on opacity {
                    NumberAnimation { duration: animDuration / 2; easing.type: Easing.InOutQuad }
                }

                Item {
                    width: 28; height: 28
                    Text {
                        anchors.centerIn: parent
                        text: "🌤"; font.pixelSize: 18
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notchContainer.openView("live")
                    }
                }

                Rectangle { width: 4; height: 4; radius: 2; color: adaptiveColors.subtleTextColor }

                Text {
                    id: timeTextFull
                    color: adaptiveColors.textColor
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.family: "monospace"
                    property date now: new Date()
                    text: now.getHours().toString().padStart(2,'0') + ":" + now.getMinutes().toString().padStart(2,'0')
                    Timer {
                        interval: 1000; running: true; repeat: true
                        onTriggered: timeTextFull.now = new Date()
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notchContainer.openView("live")
                    }
                }

                Rectangle { width: 4; height: 4; radius: 2; color: adaptiveColors.subtleTextColor }

                Item {
                    width: 28; height: 28
                    
                    Text {
                        anchors.centerIn: parent
                        text: Root.State.notifications ? Root.State.notifications.length.toString() : "0"
                        color: adaptiveColors.textColor
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        z: 1
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "🔔"; font.pixelSize: 16
                        visible: !Root.State.notifications || Root.State.notifications.length === 0
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notchContainer.openView("notifications")
                    }
                }
            }
            
            // Discrete mode row (minimal: time + notification icon)
            Row {
                id: discreteRow
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1  // Slight offset since attached to bottom
                spacing: 10
                visible: discreteMode && !volumeOverlayActive
                opacity: (discreteMode && !volumeOverlayActive) ? 1 : 0
                
                Behavior on opacity {
                    NumberAnimation { duration: animDuration / 2; easing.type: Easing.InOutQuad }
                }

                Text {
                    id: timeTextDiscrete
                    anchors.verticalCenter: parent.verticalCenter
                    color: adaptiveColors.textColor
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.family: "monospace"
                    property date now: new Date()
                    text: now.getHours().toString().padStart(2,'0') + ":" + now.getMinutes().toString().padStart(2,'0')
                    Timer {
                        interval: 1000; running: true; repeat: true
                        onTriggered: timeTextDiscrete.now = new Date()
                    }
                }

                // Notification icon (on the right side)
                Item {
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        text: Root.State.notifications && Root.State.notifications.length > 0 
                              ? Root.State.notifications.length.toString() 
                              : ""
                        color: adaptiveColors.textColor
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        z: 1
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "🔔"
                        font.pixelSize: 13
                        opacity: Root.State.notifications && Root.State.notifications.length > 0 ? 0.7 : 1.0
                    }
                }
            }
        }
    }

    // Screen view mapping
    readonly property var screenViews: ({
        "launcher": "../../screens/AppLauncher.qml",
        "live": "../../screens/LiveScreen.qml",
        "notifications": "../../screens/NotificationScreen.qml",
        "toolbar": "../../screens/ToolbarScreen.qml",
        "power": "../../screens/PowerScreen.qml"
    })

    // Dynamic screen loader component
    Component {
        id: screenLoaderComponent
        Loader {
            property string screenSource: ""
            source: screenSource
            onLoaded: {
                if (item && item.closeRequested) item.closeRequested.connect(notchContainer.closeView)
                // Focus the loaded item to enable keyboard input
                if (item) item.forceActiveFocus()
            }
        }
    }

    // View management
    function openView(viewName) {
        if (currentView === viewName) return
        if (!screenViews[viewName]) return

        var props = { screenSource: screenViews[viewName] }

        if (currentView === "default") {
            stackViewInternal.push(screenLoaderComponent, props)
        } else {
            stackViewInternal.replace(screenLoaderComponent, props)
        }
        currentView = viewName
    }

    function closeView() {
        if (currentView === "default") return
        stackViewInternal.pop()
        currentView = "default"
        closeRequested()
    }

    Keys.onEscapePressed: if (isExpanded) closeView()
    
    // Hover detection for the entire bar (used for discrete mode toggle)
    BarHoverDetector {
        onHoverChanged: (hovering) => notchContainer.barHoverChanged(hovering)
    }
}
