//@ pragma UseQApplication

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "components"
import "globals" as Root
import "globals"

ShellRoot {
    id: root

    // Current screen state (synced with main bar)
    property string currentScreen: "none"
    
    // Fullscreen detection - direct binding for reactivity
    readonly property bool isFullscreen: {
        var toplevel = ToplevelManager.activeToplevel
        if (!toplevel) return false
        return toplevel.fullscreen
    }
    
    // Screen dimensions - get from Hyprland monitor
    property int screenWidth: {
        var monitor = Hyprland.monitors.values[0]
        return monitor ? monitor.width : 1920
    }
    property int screenHeight: {
        var monitor = Hyprland.monitors.values[0]
        return monitor ? monitor.height : 1080
    }
    
    // Shared reveal logic for both bars
    function shouldRevealBar(hoverActive) {
        // Check if hovering first
        if (hoverActive) return true
        
        // Check if current workspace has any windows
        var currentWs = Root.State.activeWorkspace
        var wsData = Hyprland.workspaces.values.find(function(ws) { return ws.id === currentWs })
        
        // Check if toplevels has any items
        var hasToplevels = false
        if (wsData && wsData.toplevels && wsData.toplevels.values && wsData.toplevels.values.length > 0) {
            hasToplevels = true
        }
        
        // If workspace is empty, always show
        if (!wsData || !hasToplevels) return true
        
        // Otherwise, check if there's a focused window IN THIS WORKSPACE
        var toplevel = ToplevelManager.activeToplevel
        if (!toplevel) return true  // No toplevel, show bars
        
        // Check if the active toplevel is in the current workspace
        var toplevelAddress = toplevel.HyprlandToplevel ? toplevel.HyprlandToplevel.address : null
        
        if (toplevelAddress) {
            // Find the window in this workspace's toplevels
            var isInCurrentWorkspace = false
            if (wsData.toplevels && wsData.toplevels.values) {
                for (var i = 0; i < wsData.toplevels.values.length; i++) {
                    if (wsData.toplevels.values[i].address === toplevelAddress) {
                        isInCurrentWorkspace = true
                        break
                    }
                }
            }
            
            // If the active toplevel is NOT in this workspace, show the bars
            if (!isInCurrentWorkspace) return true
        }
        
        // The toplevel is in this workspace, check if it's activated
        return !toplevel.activated
    }
    
    // Reusable function for handling bar hover changes
    function handleBarHover(barObj, timerObj, hoverAreaObj, hovering) {
        barObj.barIsHovered = hovering
        if (hovering) {
            timerObj.stop()
            barObj.hoverActive = true
        } else {
            timerObj.restart()
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // MAIN BAR - Dynamic Island (Ambxst-style: full screen window, main bar floats)
    // ═══════════════════════════════════════════════════════════════
    PanelWindow {
        id: mainBarWindow
        // Hide when active window is fullscreen
        visible: !root.isFullscreen

        // AMBXST: Full screen window, main bar floats inside
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"

        // Hover state for discrete mode
        property bool hoverActive: false
        property bool barIsHovered: false
        
        // Discrete mode reveal logic - similar to workspace/status bars
        readonly property bool shouldBeDiscrete: {
            // If hovering, don't be discrete
            if (hoverActive) return false
            
            // If main bar is expanded, don't be discrete
            if (mainBarContent.isExpanded) return false
            
            // Check if current workspace has any windows
            var currentWs = Root.State.activeWorkspace
            var wsData = Hyprland.workspaces.values.find(function(ws) { return ws.id === currentWs })
            
            // Check if toplevels has any items
            var hasToplevels = false
            if (wsData && wsData.toplevels && wsData.toplevels.values && wsData.toplevels.values.length > 0) {
                hasToplevels = true
            }
            
            // If workspace is empty, don't be discrete
            if (!wsData || !hasToplevels) return false
            
            // Otherwise, check if there's a focused window IN THIS WORKSPACE
            var toplevel = ToplevelManager.activeToplevel
            if (!toplevel) return false  // No toplevel, don't be discrete
            
            // Check if the active toplevel is in the current workspace
            var toplevelAddress = toplevel.HyprlandToplevel ? toplevel.HyprlandToplevel.address : null
            
            if (toplevelAddress) {
                // Find the window in this workspace's toplevels
                var isInCurrentWorkspace = false
                if (wsData.toplevels && wsData.toplevels.values) {
                    for (var i = 0; i < wsData.toplevels.values.length; i++) {
                        if (wsData.toplevels.values[i].address === toplevelAddress) {
                            isInCurrentWorkspace = true
                            break
                        }
                    }
                }
                
                // If the active toplevel is NOT in this workspace, don't be discrete
                if (!isInCurrentWorkspace) return false
            }
            
            // The toplevel is in this workspace and activated, be discrete
            return toplevel.activated
        }
        
        // Timer to delay entering discrete mode after mouse leaves
        Timer {
            id: mainBarDiscreteTimer
            interval: 1000
            repeat: false
            onTriggered: {
                if (!mainBarHoverArea.containsMouse && !mainBarWindow.barIsHovered) {
                    mainBarWindow.hoverActive = false
                }
            }
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "molten-notch"
        WlrLayershell.keyboardFocus: mainBarContent.isExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        // Mask: full window when expanded (to catch outside clicks), just main bar when collapsed
        mask: Region {
            item: mainBarContent.isExpanded ? fullWindowMask : mainBarRegionContainer
        }

        // Full window mask for catching outside clicks when expanded
        Item {
            id: fullWindowMask
            anchors.fill: parent
        }

        // Click outside expanded main bar to close (full window area)
        MouseArea {
            anchors.fill: parent
            z: -1
            visible: mainBarContent.isExpanded
            onClicked: mainBarContent.closeView()
        }

        // Container for the main bar region (for masking when collapsed)
        Item {
            id: mainBarRegionContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            // In discrete mode, attach to edge (no margin); otherwise float with margin
            anchors.bottomMargin: mainBarContent.discreteMode ? 0 : 6
            width: mainBarContent.implicitWidth
            height: mainBarContent.implicitHeight
            
            Behavior on anchors.bottomMargin {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutQuart
                }
            }

            MainBar {
                id: mainBarContent
                anchors.centerIn: parent
                
                // Discrete mode binding - controlled by shell
                discreteMode: mainBarWindow.shouldBeDiscrete

                onCurrentViewChanged: {
                    root.currentScreen = currentView === "default" ? "none" : currentView
                }

                onIsExpandedChanged: {
                    // Update glass backdrop rounding dynamically when main bar expands/collapses
                    var radius = isExpanded ? Theme.containerRoundness : Theme.barRoundness
                    Hyprland.dispatch("exec hyprctl setprop title:^molten-glass-notch$ rounding " + radius)
                }
                
                onDiscreteModeChanged: {
                    // Update glass backdrop rounding when entering/exiting discrete mode
                    if (!isExpanded) {
                        var radius = discreteMode ? (discreteHeight / 2) : Theme.barRoundness
                        Hyprland.dispatch("exec hyprctl setprop title:^molten-glass-notch$ rounding " + radius)
                    }
                }

                onCloseRequested: {
                    root.currentScreen = "none"
                }
                
                onBarHoverChanged: (hovering) => {
                    mainBarWindow.barIsHovered = hovering
                    if (hovering) {
                        mainBarDiscreteTimer.stop()
                        mainBarWindow.hoverActive = true
                    } else {
                        mainBarDiscreteTimer.restart()
                    }
                }
            }
        }
        
        // Hover detection zone at the bottom center for revealing main bar from discrete mode
        MouseArea {
            id: mainBarHoverArea
            z: 100
            hoverEnabled: true
            propagateComposedEvents: true
            onPressed: (mouse) => mouse.accepted = false
            
            // Position at bottom center
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0
            width: mainBarContent.discreteMode ? 120 : mainBarContent.implicitWidth + 24
            height: 1  // Trigger only on edge hit
            
            onContainsMouseChanged: {
                if (containsMouse) {
                    mainBarDiscreteTimer.stop()
                    mainBarWindow.hoverActive = true
                } else {
                    mainBarDiscreteTimer.restart()
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // WORKSPACE BAR - Launcher, Overview, Workspaces
    // ═══════════════════════════════════════════════════════════════
    PanelWindow {
        id: workspaceBar
        visible: !root.isFullscreen

        anchors {
            bottom: true
            left: true
        }
        margins.bottom: 0
        margins.left: 0

        implicitHeight: reveal ? 56 : 1
        implicitWidth: workspaceBarContent.implicitWidth + 50

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "molten-left"
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"
        
        // Hover state with delay (Ambxst pattern)
        property bool hoverActive: false
        property bool barIsHovered: false
        
        // Reveal logic - use shared function
        readonly property bool reveal: root.shouldRevealBar(hoverActive)
        
        // Timer to delay hiding after mouse leaves
        Timer {
            id: workspaceHideTimer
            interval: 1000
            repeat: false
            onTriggered: {
                if (!workspaceHoverArea.containsMouse && !workspaceBar.barIsHovered) {
                    workspaceBar.hoverActive = false
                }
            }
        }

        // Hover detection zone - FIXED SIZE to prevent flickering
        MouseArea {
            id: workspaceHoverArea
            z: 100  // Ensure it's above the bar content
            hoverEnabled: true
            propagateComposedEvents: true
            onPressed: (mouse) => mouse.accepted = false
            
            // Position at bottom-left - ABSOLUTE position at screen bottom
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 0
            anchors.bottomMargin: 0  // Stay at absolute bottom
            width: workspaceBarContent.implicitWidth + 24  // Fixed to content size + padding
            height: 1  // Trigger only on edge hit
            
            onContainsMouseChanged: {
                if (containsMouse) {
                    workspaceHideTimer.stop()
                    workspaceBar.hoverActive = true
                } else {
                    workspaceHideTimer.restart()
                }
            }
        }

        WorkspaceBar {
            id: workspaceBarContent
            z: 1  // Below the MouseArea
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 6
            anchors.bottomMargin: 6
            showBar: workspaceBar.reveal
            onLauncherRequested: mainBarContent.openView("launcher")
            onOverviewRequested: State.toggleOverview()
            onBarHoverChanged: (hovering) => root.handleBarHover(workspaceBar, workspaceHideTimer, workspaceHoverArea, hovering)
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // STATUS BAR - Power, Toolbar, System Tray
    // ═══════════════════════════════════════════════════════════════
    PanelWindow {
        id: statusBar
        visible: !root.isFullscreen
        
        // Hover state with delay (Ambxst pattern)
        property bool hoverActive: false
        property bool barIsHovered: false
        property bool trayMenuActive: false

        anchors {
            bottom: true
            right: true
        }
        margins.bottom: 0
        margins.right: 0

        implicitHeight: reveal ? 56 : 1
        implicitWidth: statusBarContent.implicitWidth + 50

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "molten-right"
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"
        
        // Reveal logic - use shared function
        readonly property bool reveal: root.shouldRevealBar(hoverActive)
        
        // Timer to delay hiding after mouse leaves
        Timer {
            id: statusHideTimer
            interval: 1000
            repeat: false
            onTriggered: {
                if (!statusHoverArea.containsMouse && !statusBar.barIsHovered && !statusBar.trayMenuActive) {
                    statusBar.hoverActive = false
                }
            }
        }

        // Hover detection zone - FIXED SIZE to prevent flickering
        MouseArea {
            id: statusHoverArea
            z: 100  // Ensure it's above the bar content
            hoverEnabled: true
            propagateComposedEvents: true
            onPressed: (mouse) => mouse.accepted = false
            
            // Position at bottom-right - ABSOLUTE position at screen bottom
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 0
            anchors.bottomMargin: 0  // Stay at absolute bottom
            width: statusBarContent.implicitWidth + 24  // Fixed to content size + padding
            height: 1  // Trigger only on edge hit
            
            onContainsMouseChanged: {
                if (containsMouse) {
                    statusHideTimer.stop()
                    statusBar.hoverActive = true
                } else {
                    statusHideTimer.restart()
                }
            }
        }

        StatusBar {
            id: statusBarContent
            z: 1  // Below the MouseArea
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 6
            anchors.bottomMargin: 6
            parentWindow: statusBar
            showBar: statusBar.reveal
            onPowerRequested: mainBarContent.openView("power")
            onToolbarRequested: mainBarContent.openView("toolbar")
            onBarHoverChanged: (hovering) => root.handleBarHover(statusBar, statusHideTimer, statusHoverArea, hovering)
            onTrayMenuActiveChanged: (active) => {
                statusBar.trayMenuActive = active
                if (active) {
                    statusHideTimer.stop()
                    statusBar.hoverActive = true
                } else {
                    statusHideTimer.restart()
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // GLASS BACKDROPS - FloatingWindows for liquid glass effect
    // ═══════════════════════════════════════════════════════════════

    // Dummy window to absorb the first-render bug (1px, invisible)
    FloatingWindow {
        id: dummyGlassWindow
        visible: !root.isFullscreen
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

    // Workspace bar glass backdrop
    GlassBackdrop {
        backdropName: "left"
        targetWidth: workspaceBarContent.implicitWidth
        targetHeight: workspaceBarContent.implicitHeight
        screenWidth: root.screenWidth
        screenHeight: root.screenHeight
        horizontalAlign: "left"
        // Always visible - yOffset handles positioning off-screen when hidden
        backdropVisible: true
        yOffset: workspaceBarContent.yPosition  // Sync with slide animation
        startupDelay: 50
    }

    // Status bar glass backdrop
    GlassBackdrop {
        backdropName: "right"
        targetWidth: statusBarContent.implicitWidth
        targetHeight: statusBarContent.implicitHeight
        screenWidth: root.screenWidth
        screenHeight: root.screenHeight
        horizontalAlign: "right"
        // Always visible - yOffset handles positioning off-screen when hidden
        backdropVisible: true
        yOffset: statusBarContent.yPosition  // Sync with slide animation
        startupDelay: 100
    }

    // Main bar glass backdrop (declared last for proper render order)
    GlassBackdrop {
        id: mainBarGlassBackdrop
        backdropName: "notch"
        targetWidth: mainBarRegionContainer.width
        targetHeight: mainBarRegionContainer.height
        screenWidth: root.screenWidth
        screenHeight: root.screenHeight
        horizontalAlign: "center"
        startupDelay: 150
        backdropVisible: !root.isFullscreen
    }
}
