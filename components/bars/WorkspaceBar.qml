import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../globals"
import "../../globals" as Root
import "../effects"
import "../behavior"
import "../transforms"
import "../widgets"

/**
 * WorkspaceBar - Left-side bar with launcher, overview, and workspaces
 * 
 * Follows the same pattern as MainBar for expandable screen support.
 */
Item {
    id: root
    implicitWidth: sizeAnimator.animatedWidth
    implicitHeight: sizeAnimator.animatedHeight
    
    width: sizeAnimator.animatedWidth
    height: sizeAnimator.animatedHeight

    signal overviewRequested()
    signal barHoverChanged(bool hovering)
    signal closeRequested()
    
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
    
    function showTemporarily() {
        behavior.showTemporarily()
    }
    
    BarBehavior {
        id: behavior
        debugName: "WorkspaceBar"
        mode: root.mode
        barHovered: root._realHover
        hasActiveWindows: root.hasActiveWindows
        isExpanded: root.isExpanded
    }
    
    readonly property bool showBar: behavior.barVisible
    readonly property bool compactMode: behavior.isCompact
    
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
        
        discreteWidth: 100
        discreteHeight: 24
        normalHeight: 44
        collapsedPadding: 24
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
        backdropName: "left"
        horizontalAlign: "left"
        margin: root.compactMode ? 0 : 6
        explicitWidth: sizeAnimator.animatedWidth
        explicitHeight: sizeAnimator.animatedHeight
        targetRadius: sizeAnimator.animatedRadius
        flatBottom: root.compactMode && !root.isExpanded
        yOffset: barTransform.slideY
        backdropVisible: root.active
        startupDelay: 50
    }
    
    AdaptiveColors {
        id: adaptiveColors
        region: "left"
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
        "launcher": "../../screens/AppLauncher.qml"
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

            // Compact mode - just workspaces
            Row {
                id: compactRow
                anchors.centerIn: parent
                spacing: 6
                visible: root.compactMode
                opacity: root.compactMode ? 1 : 0

                WorkspacesWidget {
                    textColor: adaptiveColors.iconColor
                }
            }

            // Floating mode - launcher + overview + workspaces
            RowLayout {
                id: floatingRow
                anchors.centerIn: parent
                spacing: 6
                visible: !root.compactMode
                opacity: root.compactMode ? 0 : 1

                // Launcher button
                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: Theme.barRoundness / 2
                    color: launcherMouse.containsMouse ? Theme.current.hover : "transparent"

                    Image {
                        anchors.centerIn: parent
                        source: "image://icon/nix-snowflake"
                        sourceSize: Qt.size(22, 22)
                        width: 22
                        height: 22
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "❄"
                        font.pixelSize: 18
                        color: adaptiveColors.iconColor
                        visible: parent.children[0].status !== Image.Ready
                    }

                    MouseArea {
                        id: launcherMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openView("launcher")
                    }
                }

                // Overview button
                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 10
                    color: overviewMouse.containsMouse ? Theme.current.hover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "▦"
                        font.pixelSize: 16
                        color: adaptiveColors.iconColor
                    }

                    MouseArea {
                        id: overviewMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.overviewRequested()
                    }
                }

                // Workspaces widget
                WorkspacesWidget {
                    textColor: adaptiveColors.iconColor
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
