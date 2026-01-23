import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../globals"
import "../../globals" as Root
import "../../services"
import "../effects"
import "../behavior"
import "../transforms"

/**
 * StatusBar - Right-side bar with system tray, status indicators, and toolbar
 * 
 * Follows the same pattern as MainBar for expandable screen support.
 */
Item {
    id: root
    implicitWidth: sizeAnimator.animatedWidth
    implicitHeight: sizeAnimator.animatedHeight
    
    width: sizeAnimator.animatedWidth
    height: sizeAnimator.animatedHeight

    signal powerRequested()
    signal barHoverChanged(bool hovering)
    signal trayMenuActiveChanged(bool active)
    signal volumeScrollChanged()
    signal closeRequested()
    
    property var parentWindow: null
    
    // Screen navigation
    property string currentView: "default"
    property bool isExpanded: currentView !== "default"
    
    readonly property int animDuration: Root.State.animDuration

    // ═══════════════════════════════════════════════════════════════
    // BEHAVIOR MODE
    // ═══════════════════════════════════════════════════════════════
    
    property string mode: "dynamic"
    property bool hasActiveWindows: false
    property bool active: true
    property bool _realHover: false
    property bool _trayMenuActive: false
    
    function showTemporarily() {
        behavior.showTemporarily()
    }
    
    BarBehavior {
        id: behavior
        debugName: "StatusBar"
        mode: root.mode
        barHovered: root._realHover
        popupActive: root._trayMenuActive || root.isExpanded
        hasActiveWindows: root.hasActiveWindows
        isExpanded: root.isExpanded
    }
    
    readonly property bool showBar: behavior.barVisible
    readonly property bool compactMode: behavior.isCompact
    
    property real currentVolume: Audio.volume
    property bool volumeMuted: Audio.muted
    
    // ═══════════════════════════════════════════════════════════════
    // TRANSFORM CONTROLLERS
    // ═══════════════════════════════════════════════════════════════
    
    BarTransform {
        id: barTransform
        target: root
        showBar: root.showBar
        expanded: root.isExpanded
        discreteMode: root.compactMode
        contentWidth: stackContainer.width
        contentHeight: stackContainer.height
        animDuration: root.animDuration
        
        discreteWidth: 120
        discreteHeight: 24
        normalHeight: 44
        collapsedPadding: 16
        expandedPadding: 32
        
        discreteRadius: 12
        normalRadius: Theme.barRoundness
        expandedRadius: Theme.containerRoundness
    }
    
    SizeAnimator {
        id: sizeAnimator
        duration: root.animDuration
        expanded: root.isExpanded
        targetWidth: barTransform.barWidth
        targetHeight: barTransform.barHeight
        targetRadius: barTransform.barRadius
    }
    
    StackTransitions {
        id: stackTransitions
        duration: root.animDuration
    }
    
    transform: barTransform.slideTransform
    
    opacity: showBar ? 1.0 : 0.0
    Behavior on opacity {
        NumberAnimation {
            duration: 400
            easing.type: showBar ? Easing.OutBack : Easing.InQuad
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // VISUAL ELEMENTS
    // ═══════════════════════════════════════════════════════════════
    
    EmbeddedGlassBackdrop {
        backdropName: "right"
        horizontalAlign: "right"
        margin: root.compactMode ? 0 : 6
        explicitWidth: sizeAnimator.animatedWidth
        explicitHeight: sizeAnimator.animatedHeight
        targetRadius: sizeAnimator.animatedRadius
        flatBottom: root.compactMode && !root.isExpanded
        yOffset: barTransform.slideY
        backdropVisible: root.active
        startupDelay: 100
    }
    
    AdaptiveColors {
        id: adaptiveColors
        region: "right"
        active: root.active
    }

    ShadowBorder {
        radius: sizeAnimator.animatedRadius
        flatBottom: barTransform.flatBottom && !root.isExpanded
    }
    
    // ═══════════════════════════════════════════════════════════════
    // SCREEN NAVIGATION
    // ═══════════════════════════════════════════════════════════════
    
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
    
    readonly property var screenViews: ({
        "toolbar": "../../screens/ToolbarScreen.qml"
    })
    
    Component {
        id: screenLoaderComponent
        Loader {
            property string screenSource: ""
            source: screenSource
            onLoaded: {
                if (item && item.closeRequested) item.closeRequested.connect(root.closeView)
                if (item) item.forceActiveFocus()
            }
        }
    }

    property string activeTrayItem: ""
    
    function clearTrayMenu() {
        activeTrayItem = ""
    }
    
    QsMenuAnchor {
        id: trayMenuAnchor
        anchor.window: root.parentWindow
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        
        onClosed: {
            root.activeTrayItem = ""
            root._trayMenuActive = false
            root.trayMenuActiveChanged(false)
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STACK CONTAINER
    // ═══════════════════════════════════════════════════════════════
    
    Item {
        id: stackContainer
        anchors.centerIn: parent
        width: stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitWidth + (root.isExpanded ? 32 : 0) : 0
        height: stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitHeight + (root.isExpanded ? 32 : 0) : 0
        clip: true

        StackView {
            id: stackViewInternal
            anchors.fill: parent
            anchors.margins: root.isExpanded ? 16 : 0
            initialItem: defaultViewComponent

            pushEnter: stackTransitions.pushEnter
            pushExit: stackTransitions.pushExit
            popEnter: stackTransitions.popEnter
            popExit: stackTransitions.popExit
            replaceEnter: stackTransitions.replaceEnter
            replaceExit: stackTransitions.replaceExit
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // DEFAULT VIEW
    // ═══════════════════════════════════════════════════════════════
    
    Component {
        id: defaultViewComponent
        Item {
            implicitWidth: root.compactMode ? compactRow.implicitWidth : floatingRow.implicitWidth
            implicitHeight: root.compactMode ? 20 : 36

            // Compact mode row
            Row {
                id: compactRow
                anchors.centerIn: parent
                spacing: 6
                visible: root.compactMode
                opacity: root.compactMode ? 1 : 0

                // Tray icons (compact)
                RowLayout {
                    spacing: 4
                    Repeater {
                        model: SystemTray.items
                        delegate: MouseArea {
                            required property SystemTrayItem modelData
                            property string trayId: modelData.id
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: function(mouse) {
                                if (mouse.button === Qt.LeftButton) {
                                    modelData.activate()
                                } else if (mouse.button === Qt.RightButton && modelData.hasMenu && root.parentWindow) {
                                    root.activeTrayItem = trayId
                                    root._trayMenuActive = true
                                    root.trayMenuActiveChanged(true)
                                    trayMenuAnchor.menu = modelData.menu
                                    var iconPos = mapToItem(null, width / 2, 0)
                                    trayMenuAnchor.anchor.rect = Qt.rect(iconPos.x, iconPos.y, 1, 1)
                                    trayMenuAnchor.open()
                                }
                            }

                            IconImage {
                                source: modelData.icon
                                anchors.centerIn: parent
                                implicitWidth: 16
                                implicitHeight: 16
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "●"
                                font.pixelSize: 10
                                color: adaptiveColors.iconColor
                                visible: parent.children[0].status !== Image.Ready
                            }
                        }
                    }
                }

                // Volume icon (compact)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.volumeMuted || root.currentVolume === 0 ? "🔇" : (root.currentVolume < 0.33 ? "🔉" : "🔊")
                    font.pixelSize: 12
                    
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: Audio.toggleMute()
                        onWheel: function(wheel) {
                            if (wheel.angleDelta.y > 0) Audio.incrementVolume()
                            else Audio.decrementVolume()
                            root.volumeScrollChanged()
                        }
                    }
                }
            }

            // Floating mode row
            RowLayout {
                id: floatingRow
                anchors.centerIn: parent
                spacing: 8
                visible: !root.compactMode
                opacity: root.compactMode ? 0 : 1

                // System tray
                Item {
                    Layout.preferredWidth: trayLayout.implicitWidth + 16
                    Layout.preferredHeight: 36

                    RowLayout {
                        id: trayLayout
                        anchors.centerIn: parent
                        spacing: 6

                        Repeater {
                            model: SystemTray.items
                            delegate: MouseArea {
                                id: trayItem
                                required property SystemTrayItem modelData
                                property string trayId: modelData.id
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        modelData.activate()
                                    } else if (mouse.button === Qt.RightButton && modelData.hasMenu && root.parentWindow) {
                                        root.activeTrayItem = trayId
                                        root._trayMenuActive = true
                                        root.trayMenuActiveChanged(true)
                                        trayMenuAnchor.menu = modelData.menu
                                        var iconPos = trayItem.mapToItem(null, trayItem.width / 2, 0)
                                        trayMenuAnchor.anchor.rect = Qt.rect(iconPos.x, iconPos.y, 1, 1)
                                        trayMenuAnchor.open()
                                    }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width + 4
                                    height: parent.height + 4
                                    radius: 4
                                    color: adaptiveColors.textColor
                                    visible: root.activeTrayItem === trayId
                                    opacity: 0.1
                                }

                                IconImage {
                                    id: trayIcon
                                    source: trayItem.modelData.icon
                                    anchors.centerIn: parent
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "●"
                                    font.pixelSize: 14
                                    color: adaptiveColors.iconColor
                                    visible: trayIcon.status !== Image.Ready
                                }
                            }
                        }
                    }
                }

                // Status indicators - clickable for toolbar
                Item {
                    Layout.preferredWidth: statusLayout.implicitWidth + 16
                    Layout.preferredHeight: 36
                    
                    RowLayout {
                        id: statusLayout
                        anchors.centerIn: parent
                        spacing: 6

                        // Volume
                        Item {
                            width: 24; height: 24
                            Text {
                                anchors.centerIn: parent
                                text: root.volumeMuted || root.currentVolume === 0 ? "🔇" : (root.currentVolume < 0.33 ? "🔉" : "🔊")
                                font.pixelSize: 14
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: Audio.toggleMute()
                                onWheel: function(wheel) {
                                    if (wheel.angleDelta.y > 0) Audio.incrementVolume()
                                    else Audio.decrementVolume()
                                    root.volumeScrollChanged()
                                }
                            }
                        }

                        // Network
                        Item {
                            width: 24; height: 24
                            Text {
                                anchors.centerIn: parent
                                text: Network.wifiEnabled ? (Network.wifiConnected ? "📶" : "📡") : "📵"
                                font.pixelSize: 14
                            }
                        }

                        // Bluetooth
                        Item {
                            width: 24; height: 24
                            visible: Bluetooth.enabled
                            Text {
                                anchors.centerIn: parent
                                text: Bluetooth.connected ? "🔷" : "📳"
                                font.pixelSize: 12
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openView("toolbar")
                    }
                }

                // Power button
                Item {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36

                    Text {
                        anchors.centerIn: parent
                        text: "⏻"
                        font.pixelSize: 15
                        color: powerMouse.containsMouse ? "#ff6b6b" : adaptiveColors.iconColor
                    }

                    MouseArea {
                        id: powerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.powerRequested()
                    }
                }
            }
        }
    }
    
    Keys.onEscapePressed: if (isExpanded) closeView()
    
    BarHoverDetector {
        onHoverChanged: (hovering) => {
            root._realHover = hovering
            root.barHoverChanged(hovering)
        }
    }
}
