import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".." as Root
import ".."

// Exact Ambxst animation structure
Item {
    id: notchContainer

    property string currentView: "default"
    property bool isExpanded: currentView !== "default"
    property bool screenNotchOpen: isExpanded

    signal closeRequested()

    // Ambxst uses 300ms
    property int animDuration: Root.State.animDuration
    
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
    implicitWidth: screenNotchOpen 
        ? Math.max(stackContainer.width + 32 + animationTrigger * 0, 290) 
        : stackContainer.width + 24
    implicitHeight: screenNotchOpen 
        ? Math.max(stackContainer.height + 32 + animationTrigger * 0, 44) 
        : 44

    // Ambxst: Behavior on implicitWidth/Height with conditional easing
    Behavior on implicitWidth {
        enabled: (screenNotchOpen || stackViewInternal.busy) && animDuration > 0
        NumberAnimation {
            duration: animDuration
            easing.type: screenNotchOpen ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: screenNotchOpen ? 1.8 : 1.0
        }
    }

    Behavior on implicitHeight {
        enabled: (screenNotchOpen || stackViewInternal.busy) && animDuration > 0
        NumberAnimation {
            duration: animDuration
            easing.type: screenNotchOpen ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: screenNotchOpen ? 1.8 : 1.0
        }
    }

    ShadowBorder {
        radius: screenNotchOpen ? Theme.containerRoundness : Theme.barRoundness
        
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
            implicitWidth: defaultRow.implicitWidth
            implicitHeight: 36

            RowLayout {
                id: defaultRow
                anchors.centerIn: parent
                spacing: 10

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
                    id: timeText
                    color: adaptiveColors.textColor
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.family: "monospace"
                    property date now: new Date()
                    text: now.getHours().toString().padStart(2,'0') + ":" + now.getMinutes().toString().padStart(2,'0')
                    Timer {
                        interval: 1000; running: true; repeat: true
                        onTriggered: timeText.now = new Date()
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
        }
    }

    // Screen view mapping
    readonly property var screenViews: ({
        "launcher": "../screens/AppLauncher.qml",
        "live": "../screens/LiveScreen.qml",
        "notifications": "../screens/NotificationScreen.qml",
        "toolbar": "../screens/ToolbarScreen.qml",
        "power": "../screens/PowerScreen.qml"
    })

    // Dynamic screen loader component
    Component {
        id: screenLoaderComponent
        Loader {
            property string screenSource: ""
            source: screenSource
            onLoaded: if (item && item.closeRequested) item.closeRequested.connect(notchContainer.closeView)
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
}
