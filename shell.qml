import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "components"

ShellRoot {
    id: root

    // Current screen state (synced with notch)
    property string currentScreen: "none"
    
    // Screen dimensions - get from Hyprland monitor
    property int screenWidth: {
        var monitor = Hyprland.monitors.values[0]
        return monitor ? monitor.width : 1920
    }
    property int screenHeight: {
        var monitor = Hyprland.monitors.values[0]
        return monitor ? monitor.height : 1080
    }

    // ═══════════════════════════════════════════════════════════════
    // NOTCH - Dynamic Island (Ambxst-style: full screen window, notch floats)
    // ═══════════════════════════════════════════════════════════════
    PanelWindow {
        id: notchWindow
        visible: !State.isFullscreen

        // AMBXST: Full screen window, notch floats inside
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "molten-notch"
        WlrLayershell.keyboardFocus: notchContent.isExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        // Mask: full window when expanded (to catch outside clicks), just notch when collapsed
        mask: Region {
            item: notchContent.isExpanded ? fullWindowMask : notchRegionContainer
        }

        // Full window mask for catching outside clicks when expanded
        Item {
            id: fullWindowMask
            anchors.fill: parent
        }

        // Click outside expanded notch to close (full window area)
        MouseArea {
            anchors.fill: parent
            z: -1
            visible: notchContent.isExpanded
            onClicked: notchContent.closeView()
        }

        // Container for the notch region (for masking when collapsed)
        Item {
            id: notchRegionContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            width: notchContent.implicitWidth
            height: notchContent.implicitHeight

            Notch {
                id: notchContent
                anchors.centerIn: parent

                onCurrentViewChanged: {
                    root.currentScreen = currentView === "default" ? "none" : currentView
                }

                onIsExpandedChanged: {
                    // Update glass backdrop rounding dynamically when notch expands/collapses
                    var radius = isExpanded ? Theme.containerRoundness : Theme.barRoundness
                    Hyprland.dispatch("exec hyprctl setprop title:^molten-glass-notch$ rounding " + radius)
                }

                onCloseRequested: {
                    root.currentScreen = "none"
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // LEFT BAR - Launcher, Overview, Workspaces
    // ═══════════════════════════════════════════════════════════════
    PanelWindow {
        id: leftBar
        visible: !State.isFullscreen

        anchors {
            bottom: true
            left: true
        }
        margins.bottom: 0
        margins.left: 0

        implicitHeight: 100
        implicitWidth: leftBarContent.implicitWidth + 50

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "molten-left"
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"

        property bool hovered: leftHoverArea.containsMouse

        // Extended hover detection zone
        MouseArea {
            id: leftHoverArea
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            onPressed: (mouse) => mouse.accepted = false
        }

        LeftBar {
            id: leftBarContent
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 6
            anchors.bottomMargin: 6
            showBar: !State.hasActiveWindows || leftBar.hovered
            onLauncherRequested: notchContent.openView("launcher")
            onOverviewRequested: State.toggleOverview()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // RIGHT BAR - Power, Toolbar, System Tray
    // ═══════════════════════════════════════════════════════════════
    PanelWindow {
        id: rightBar
        visible: !State.isFullscreen

        anchors {
            bottom: true
            right: true
        }
        margins.bottom: 0
        margins.right: 0

        implicitHeight: 100
        implicitWidth: rightBarContent.implicitWidth + 50

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "molten-right"
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"

        property bool hovered: rightHoverArea.containsMouse

        // Extended hover detection zone
        MouseArea {
            id: rightHoverArea
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            onPressed: (mouse) => mouse.accepted = false
        }

        RightBar {
            id: rightBarContent
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 6
            anchors.bottomMargin: 6
            showBar: !State.hasActiveWindows || rightBar.hovered
            onPowerRequested: notchContent.openView("power")
            onToolbarRequested: notchContent.openView("toolbar")
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // GLASS BACKDROPS - FloatingWindows for liquid glass effect
    // ═══════════════════════════════════════════════════════════════

    // Dummy window to absorb the first-render bug (1px, invisible)
    FloatingWindow {
        id: dummyGlassWindow
        visible: !State.isFullscreen
        title: "molten-glass-dummy"
        
        implicitWidth: 1
        implicitHeight: 1
        
        color: "transparent"
        
        property bool windowReady: false
        
        Timer {
            interval: 10
            running: dummyGlassWindow.visible
            onTriggered: {
                dummyGlassWindow.windowReady = true
                Hyprland.dispatch("resizewindowpixel exact 1 1,title:^molten-glass-dummy$")
                Hyprland.dispatch("movewindowpixel exact 0 0,title:^molten-glass-dummy$")
            }
        }
        
        Rectangle { width: 1; height: 1; color: "transparent" }
    }

    // Left bar glass backdrop
    GlassBackdrop {
        backdropName: "left"
        targetWidth: leftBarContent.implicitWidth
        targetHeight: leftBarContent.implicitHeight
        screenWidth: root.screenWidth
        screenHeight: root.screenHeight
        horizontalAlign: "left"
        backdropVisible: leftBarContent.opacity > 0
        startupDelay: 50
    }

    // Right bar glass backdrop
    GlassBackdrop {
        backdropName: "right"
        targetWidth: rightBarContent.implicitWidth
        targetHeight: rightBarContent.implicitHeight
        screenWidth: root.screenWidth
        screenHeight: root.screenHeight
        horizontalAlign: "right"
        backdropVisible: rightBarContent.opacity > 0
        startupDelay: 100
    }

    // Notch glass backdrop (declared last for proper render order)
    GlassBackdrop {
        id: notchGlassBackdrop
        backdropName: "notch"
        targetWidth: notchRegionContainer.width
        targetHeight: notchRegionContainer.height
        screenWidth: root.screenWidth
        screenHeight: root.screenHeight
        horizontalAlign: "center"
        startupDelay: 150
    }
}
