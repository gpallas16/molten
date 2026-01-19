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
    
    // ═══════════════════════════════════════════════════════════════
    // KEYBIND HANDLER - Listen for Hyprland global shortcuts
    // ═══════════════════════════════════════════════════════════════
    
    Connections {
        target: Root.KeybindHandler
        
        function onKeybindTriggered(action) {
            // Toggle behavior: if the requested view is already open, close it
            if (mainBarContent.currentView === action) {
                mainBarContent.closeView()
                return
            }
            
            switch (action) {
                case "launcher":
                    mainBarContent.openView("launcher")
                    break
                case "notifications":
                    mainBarContent.openView("notifications")
                    break
                case "toolbar":
                    mainBarContent.openView("toolbar")
                    break
                case "power":
                    mainBarContent.openView("power")
                    break
                case "live":
                    mainBarContent.openView("live")
                    break
                default:
                    console.log("Unknown action:", action)
            }
        }
    }
    
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
    
    // When hovering the bar itself, keep it visible
    function handleBarHover(barObj, hideTimer, showTimer, hovering) {
        barObj.barIsHovered = hovering
        if (hovering) {
            hideTimer.stop()
        } else {
            hideTimer.restart()
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

        // State: "discrete" (docked), "hidden", "floating"
        property string barState: "discrete"
        
        // Discrete mode: docked to edge when there are active windows
        readonly property bool shouldBeDiscrete: {
            if (mainBarContent.isExpanded) return false
            
            var currentWs = Root.State.activeWorkspace
            var wsData = Hyprland.workspaces.values.find(function(ws) { return ws.id === currentWs })
            
            if (!wsData || !wsData.toplevels || !wsData.toplevels.values || wsData.toplevels.values.length === 0) {
                return false
            }
            
            var toplevel = ToplevelManager.activeToplevel
            if (!toplevel) return false
            
            var toplevelAddress = toplevel.HyprlandToplevel ? toplevel.HyprlandToplevel.address : null
            if (!toplevelAddress) return false
            
            for (var i = 0; i < wsData.toplevels.values.length; i++) {
                if (wsData.toplevels.values[i].address === toplevelAddress) {
                    return toplevel.activated
                }
            }
            return false
        }
        
        // When conditions change, switch states appropriately
        onShouldBeDiscreteChanged: {
            if (!shouldBeDiscrete) {
                // No windows - always go to floating (from discrete or hidden)
                if (barState === "discrete" || barState === "hidden") {
                    barState = "floating"
                }
            } else {
                // Has windows - go to discrete if not being hovered
                if (barState === "floating" && !barIsHovered) {
                    barState = "discrete"
                }
            }
        }
        
        // Timer to return from floating to discrete
        Timer {
            id: mainBarDiscreteTimer
            interval: 1000
            onTriggered: {
                if (mainBarWindow.barState === "floating" && !mainBarWindow.barIsHovered && mainBarWindow.shouldBeDiscrete) {
                    mainBarWindow.barState = "discrete"
                }
                // If shouldBeDiscrete is false, stay floating
            }
        }
        
        property bool barIsHovered: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "molten-notch"
        WlrLayershell.keyboardFocus: mainBarContent.isExpanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        // Mask: full window when expanded, bar + edge trigger when collapsed
        mask: Region {
            item: mainBarContent.isExpanded ? fullWindowMask : mainBarMaskContainer
        }

        // Full window mask for catching outside clicks when expanded
        Item {
            id: fullWindowMask
            anchors.fill: parent
        }
        
        // Combined mask for bar region + edge trigger area (so edge works when bar is hidden)
        Item {
            id: mainBarMaskContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: Math.max(mainBarRegionContainer.width, mainBarEdgeTrigger.width)
            height: mainBarRegionContainer.height + 6 + 10  // bar + margin + edge trigger buffer
        }
        
        // Hover zone that stays at discrete position - detects when mouse leaves the bar area
        MouseArea {
            id: discreteHoverZone
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: mainBarContent.implicitWidth
            height: mainBarContent.implicitHeight
            hoverEnabled: true
            propagateComposedEvents: true
            acceptedButtons: Qt.NoButton
            
            onContainsMouseChanged: {
                if (mainBarWindow.barState === "hidden") {
                    if (containsMouse) {
                        // Mouse still in zone - stay hidden
                    } else {
                        // Mouse left zone - show discrete
                        mainBarWindow.barState = "discrete"
                    }
                }
            }
        }
        
        // Edge trigger zone - always at bottom edge, always in mask
        Item {
            id: mainBarEdgeTrigger
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: 200
            height: 10
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
            // Position based on state: discrete=docked, floating=with margin
            // Hidden state is now handled by MainBar's showBar property with slide animation
            anchors.bottomMargin: {
                if (mainBarWindow.barState === "floating") return 6
                return 0  // discrete - docked (hidden uses showBar: false)
            }
            width: mainBarContent.implicitWidth
            height: mainBarContent.implicitHeight
            
            // Y position for glass backdrop sync - use MainBar's transform position
            property real yPosition: mainBarContent.yPosition
            
            Behavior on anchors.bottomMargin {
                NumberAnimation { duration: 300; easing.type: Easing.OutQuart }
            }

            MainBar {
                id: mainBarContent
                anchors.centerIn: parent
                
                // Discrete mode = docked or hidden state (keep discrete look while sliding down)
                discreteMode: (mainBarWindow.barState === "discrete" || mainBarWindow.barState === "hidden") && mainBarWindow.shouldBeDiscrete
                
                // Slide down when hidden (like WorkspaceBar and StatusBar)
                showBar: mainBarWindow.barState !== "hidden"

                onCurrentViewChanged: {
                    root.currentScreen = currentView === "default" ? "none" : currentView
                }

                onIsExpandedChanged: {
                    updateGlassBackdropRounding()
                }
                
                onDiscreteModeChanged: {
                    updateGlassBackdropRounding()
                }
                
                onDiscreteFlatBottomChanged: {
                    updateGlassBackdropRounding()
                }
                
                function updateGlassBackdropRounding() {
                    var radius
                    if (isExpanded) {
                        radius = Theme.containerRoundness
                    } else if (discreteMode) {
                        radius = 12
                    } else {
                        radius = Theme.barRoundness
                    }
                    Hyprland.dispatch("exec hyprctl setprop title:^molten-glass-notch$ rounding " + Math.round(radius))
                }

                onCloseRequested: {
                    root.currentScreen = "none"
                }
                
                // Volume overlay state change - switch to floating when active
                onVolumeOverlayStateChanged: (active) => {
                    if (active) {
                        // Store the current state before switching
                        mainBarContent.previousBarState = mainBarWindow.barState
                        // Switch to floating to show the volume overlay properly
                        mainBarWindow.barState = "floating"
                        mainBarDiscreteTimer.stop()
                    } else {
                        // Return to previous state after volume overlay hides
                        if (mainBarContent.previousBarState === "discrete" && mainBarWindow.shouldBeDiscrete) {
                            mainBarWindow.barState = "discrete"
                        } else if (mainBarContent.previousBarState === "hidden" && mainBarWindow.shouldBeDiscrete) {
                            mainBarWindow.barState = "discrete"
                        }
                        // Otherwise stay floating (or let the normal state machine handle it)
                        mainBarDiscreteTimer.restart()
                    }
                }
                
                // Simple state machine
                onBarHoverChanged: (hovering) => {
                    mainBarWindow.barIsHovered = hovering
                    
                    if (hovering) {
                        mainBarDiscreteTimer.stop()
                        // Discrete + hover → Hidden
                        if (mainBarWindow.barState === "discrete") {
                            mainBarWindow.barState = "hidden"
                        }
                        // Floating + hover → stay floating
                    } else {
                        // Floating + leave → start timer to go discrete (but not if volume overlay is active)
                        if (mainBarWindow.barState === "floating" && !mainBarContent.volumeOverlayActive) {
                            mainBarDiscreteTimer.restart()
                        }
                        // Hidden state is handled by discreteHoverZone
                    }
                }
            }
        }
        
        // Edge detection - brings bar back from hidden as floating
        MouseArea {
            id: mainBarHoverArea
            z: 100
            hoverEnabled: true
            propagateComposedEvents: true
            onPressed: (mouse) => mouse.accepted = false
            
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: 200
            height: 1
            
            onContainsMouseChanged: {
                if (containsMouse) {
                    // Edge hit → Floating (from any state)
                    mainBarDiscreteTimer.stop()
                    mainBarWindow.barState = "floating"
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
        
        // Auto-reveal when workspace changes
        Connections {
            target: Root.State
            function onActiveWorkspaceChanged() {
                workspaceBar.hoverActive = true
                workspaceHideTimer.restart()
            }
        }
        
        // Timer to delay hiding after mouse leaves
        Timer {
            id: workspaceHideTimer
            interval: 1000
            repeat: false
            onTriggered: {
                if (!workspaceBar.barIsHovered && !workspaceHoverArea.containsMouse) {
                    workspaceBar.hoverActive = false
                }
            }
        }
        
        // Timer to delay showing when mouse enters edge
        Timer {
            id: workspaceShowTimer
            interval: 500
            repeat: false
            onTriggered: {
                workspaceBar.hoverActive = true
                workspaceHideTimer.restart()
            }
        }

        // Hover detection zone at bottom edge
        MouseArea {
            id: workspaceHoverArea
            z: 100
            hoverEnabled: true
            propagateComposedEvents: true
            onPressed: (mouse) => mouse.accepted = false
            // Pass wheel events through to children
            onWheel: (wheel) => wheel.accepted = false
            
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 0
            anchors.bottomMargin: 0
            width: workspaceBarContent.implicitWidth + 24
            height: 56  // Same as bar height to prevent false leave events
            
            onContainsMouseChanged: {
                if (containsMouse) {
                    if (!workspaceBar.hoverActive) {
                        workspaceShowTimer.restart()
                    }
                } else {
                    workspaceShowTimer.stop()
                    if (workspaceBar.hoverActive && !workspaceBar.barIsHovered) {
                        workspaceHideTimer.restart()
                    }
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
            onBarHoverChanged: (hovering) => root.handleBarHover(workspaceBar, workspaceHideTimer, workspaceShowTimer, hovering)
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
                if (!statusBar.barIsHovered && !statusBar.trayMenuActive && !statusHoverArea.containsMouse) {
                    statusBar.hoverActive = false
                }
            }
        }
        
        // Timer to delay showing when mouse enters edge
        Timer {
            id: statusShowTimer
            interval: 500
            repeat: false
            onTriggered: {
                statusBar.hoverActive = true
                statusHideTimer.restart()
            }
        }

        // Hover detection zone at bottom edge
        MouseArea {
            id: statusHoverArea
            z: 100
            hoverEnabled: true
            propagateComposedEvents: true
            onPressed: (mouse) => mouse.accepted = false
            // Pass wheel events through to children
            onWheel: (wheel) => wheel.accepted = false
            
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 0
            anchors.bottomMargin: 0
            width: statusBarContent.implicitWidth + 24
            height: 56  // Same as bar height to prevent false leave events
            
            onContainsMouseChanged: {
                if (containsMouse) {
                    if (!statusBar.hoverActive) {
                        statusShowTimer.restart()
                    }
                } else {
                    statusShowTimer.stop()
                    if (statusBar.hoverActive && !statusBar.barIsHovered) {
                        statusHideTimer.restart()
                    }
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
            onBarHoverChanged: (hovering) => root.handleBarHover(statusBar, statusHideTimer, statusShowTimer, hovering)
            onTrayMenuActiveChanged: (active) => {
                statusBar.trayMenuActive = active
                if (active) {
                    statusHideTimer.stop()
                    statusBar.hoverActive = true
                } else {
                    statusHideTimer.restart()
                }
            }
            // GNOME-like volume scroll - trigger MainBar volume overlay
            onVolumeScrollChanged: {
                mainBarContent.showVolumeOverlay()
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
                Hyprland.dispatch("movewindowpixel exact -10 -10,title:^molten-glass-dummy$")
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
        // Margin changes: 0 when docked (discrete), 6 when floating
        margin: mainBarWindow.barState === "discrete" ? 0 : 6
        // Always visible - yOffset handles positioning off-screen when hidden
        backdropVisible: !root.isFullscreen
        yOffset: mainBarRegionContainer.yPosition  // Sync with slide animation
        startupDelay: 150
        
        // Sync discrete mode state from main bar
        discreteMode: mainBarContent.discreteMode
        targetRadius: {
            if (mainBarContent.discreteMode && !mainBarContent.isExpanded) {
                return 12  // Discrete notch roundness
            } else if (mainBarContent.isExpanded) {
                return Theme.containerRoundness
            } else {
                return Theme.barRoundness
            }
        }
        // Flat bottom in discrete mode (attached to edge)
        flatBottom: mainBarContent.discreteFlatBottom
    }
}
