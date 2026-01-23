//@ pragma UseQApplication

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import "components"
import "config"
import "globals" as Root
import "globals"
import "services"

ShellRoot {
    id: root

    // Current screen state (synced with main bar)
    property string currentScreen: "none"
    
    // ═══════════════════════════════════════════════════════════════
    // WALLPAPER - Native wallpaper rendering (one per screen)
    // ═══════════════════════════════════════════════════════════════
    Variants {
        model: Quickshell.screens
        
        Wallpaper {
            required property var modelData
            screen: modelData
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // KEYBIND HANDLER - Listen for Hyprland global shortcuts
    // ═══════════════════════════════════════════════════════════════

    Connections {
        target: Root.KeybindHandler
        
        function onKeybindTriggered(action) {
            // Reset activity timer on any keybind
            root.resetActivityTimer()
            
            // Handle volume/brightness overlay triggers (don't toggle, just show overlay)
            switch (action) {
                case "volume_up":
                case "volume_down":
                case "volume_mute":
                    mainBarContent.showVolumeOverlay()
                    return
                case "brightness_up":
                case "brightness_down":
                    mainBarContent.showBrightnessOverlay()
                    return
                // Screenshot actions - close any open UI first, then capture
                case "screenshot_area":
                    mainBarContent.closeView()
                    Screenshot.capture("area")
                    return
                case "screenshot_screen":
                    mainBarContent.closeView()
                    Screenshot.capture("screen")
                    return
                case "screenshot_window":
                    mainBarContent.closeView()
                    Screenshot.capture("window")
                    return
                case "color_picker":
                    mainBarContent.closeView()
                    Screenshot.pickColor()
                    return
                case "screen_record":
                    mainBarContent.closeView()
                    Screenshot.startRecording()
                    return
            }
            
            // Toggle behavior: if the requested view is already open, close it
            if (mainBarContent.currentView === action) {
                mainBarContent.closeView()
                return
            }
            // Also check workspace and status bar current views
            if (workspaceBarContent.currentView === action) {
                workspaceBarContent.closeView()
                return
            }
            if (statusBarContent.currentView === action) {
                statusBarContent.closeView()
                return
            }
            
            switch (action) {
                case "launcher":
                    // Close other bars if open
                    mainBarContent.closeView()
                    statusBarContent.closeView()
                    workspaceBarContent.openView("launcher")
                    break
                case "notifications":
                    // Notifications merged into live screen
                    workspaceBarContent.closeView()
                    statusBarContent.closeView()
                    mainBarContent.openView("live")
                    break
                case "toolbar":
                    // Close other bars if open
                    mainBarContent.closeView()
                    workspaceBarContent.closeView()
                    statusBarContent.openView("toolbar")
                    break
                case "power":
                    workspaceBarContent.closeView()
                    statusBarContent.closeView()
                    mainBarContent.openView("power")
                    break
                case "live":
                    workspaceBarContent.closeView()
                    statusBarContent.closeView()
                    mainBarContent.openView("live")
                    break
                case "clipboard":
                    workspaceBarContent.closeView()
                    statusBarContent.closeView()
                    mainBarContent.openView("clipboard")
                    break
                default:
                    console.log("Unknown action:", action)
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // AUTO-SUSPEND - Sleep after 15 minutes of inactivity (if not caffeine mode)
    // ═══════════════════════════════════════════════════════════════
    
    // Track last user activity
    property real lastActivityTime: Date.now()
    
    function resetActivityTimer() {
        lastActivityTime = Date.now()
    }
    
    // Check if any media is currently playing (MPRIS)
    readonly property bool mediaIsPlaying: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing) {
                return true
            }
        }
        return false
    }
    
    // Check for inactivity every minute
    Timer {
        id: autoSuspendTimer
        interval: 60000  // 1 minute
        running: true
        repeat: true
        onTriggered: {
            // Skip if caffeine mode is enabled (using the Caffeine service)
            if (Caffeine.enabled) return
            
            // Skip if media is playing
            if (root.mediaIsPlaying) {
                root.resetActivityTimer()  // Reset timer while media is playing
                return
            }
            
            var idleTime = Date.now() - lastActivityTime
            var fifteenMinutes = 15 * 60 * 1000  // 15 minutes in ms
            
            if (idleTime >= fifteenMinutes) {
                console.log("Auto-suspend: 15 minutes idle, suspending...")
                suspendProc.running = true
                suspendProc.running = true
            }
        }
    }
    
    // Process to suspend the system
    Process {
        id: suspendProc
        command: ["systemctl", "suspend"]
    }
    
    // Reset activity on Hyprland events
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // Any Hyprland event counts as user activity
            if (["activewindow", "focusedmon", "openwindow", "closewindow", 
                 "workspace", "moveworkspace", "fullscreen", "urgent",
                 "submap", "movewindow", "resizewindow"].includes(event.name)) {
                root.resetActivityTimer()
            }
        }
    }
    
    // Fullscreen detection - direct binding for reactivity
    readonly property bool isFullscreen: {
        var toplevel = ToplevelManager.activeToplevel
        if (!toplevel) return false
        return toplevel.fullscreen
    }

        // ═══════════════════════════════════════════════════════════════
    // DUMMY GLASS WINDOW - Absorbs first-render bug
    // ═══════════════════════════════════════════════════════════════
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
    
    // ═══════════════════════════════════════════════════════════════
    // EXCLUSIVE ZONE - Invisible bar to reserve screen space
    // Visible for all modes except "hidden"
    // ═══════════════════════════════════════════════════════════════
    PanelWindow {
        id: exclusiveZoneBar
        visible: Config.mainBarMode !== "hidden" || 
                 Config.workspaceBarMode !== "hidden" || 
                 Config.statusBarMode !== "hidden"
        
        anchors {
            bottom: true
            left: true
            right: true
        }
        
        // Minimal exclusive zone - just enough for compact bars
        // Compact height (24) + tiny margin (2) = 26
        readonly property int zoneHeight: 16
        
        implicitHeight: zoneHeight
        color: "transparent"
        
        WlrLayershell.layer: WlrLayer.Bottom  // Below everything, just for reserving space
        WlrLayershell.namespace: "molten-exclusive"
        exclusiveZone: zoneHeight
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
        // Negative margin to counteract exclusive zone push
        margins.bottom: exclusiveZoneBar.visible ? -exclusiveZoneBar.zoneHeight : 0

        color: "transparent"

        // Track dependencies explicitly for hasActiveWindows reactivity
        property var _activeToplevel: ToplevelManager.activeToplevel
        property bool _toplevelActivated: _activeToplevel ? _activeToplevel.activated : false
        
        // Detect active windows in current workspace
        readonly property bool hasActiveWindows: {
            if (mainBarContent.isExpanded) return false
            
            // Use tracked properties for reactivity
            var activated = _toplevelActivated
            var currentWs = Root.State.activeWorkspace
            var wsData = Hyprland.workspaces.values.find(function(ws) { return ws.id === currentWs })
            
            if (!wsData || !wsData.toplevels || !wsData.toplevels.values || wsData.toplevels.values.length === 0) {
                return false
            }
            
            var toplevel = _activeToplevel
            if (!toplevel) return false
            
            var toplevelAddress = toplevel.HyprlandToplevel ? toplevel.HyprlandToplevel.address : null
            if (!toplevelAddress) return false
            
            for (var i = 0; i < wsData.toplevels.values.length; i++) {
                if (wsData.toplevels.values[i].address === toplevelAddress) {
                    return activated
                }
            }
            return false
        }

        // Convenience property for barState (read from MainBar's internal behavior)
        readonly property string barState: mainBarContent.internalState
        
        property bool barIsHovered: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "molten-notch"
        WlrLayershell.keyboardFocus: mainBarContent.isExpanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        // Note: Can't use exclusiveZone here - window is full-screen for click handling
        // Side bars handle the exclusive zone reservation

        // Mask: full window when expanded, bar area otherwise
        mask: Region {
            item: mainBarContent.isExpanded ? fullWindowMask : mainBarMask
        }

        // Full window mask for catching outside clicks when expanded
        Item {
            id: fullWindowMask
            anchors.fill: parent
        }
        
        // Bar mask - covers just the bar area
        Item {
            id: mainBarMask
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: mainBarRegionContainer.width + 20
            height: mainBarRegionContainer.height + 20
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
                if (mainBarWindow.barState === "floating") return 2
                return 0  // discrete - docked (hidden uses showBar: false)
            }
            width: mainBarContent.implicitWidth
            height: mainBarContent.implicitHeight
            
            Behavior on anchors.bottomMargin {
                NumberAnimation { duration: 300; easing.type: Easing.OutQuart }
            }

            MainBar {
                id: mainBarContent
                anchors.centerIn: parent
                
                // Behavior inputs - MainBar now has its own BarBehavior
                mode: Config.mainBarMode
                hasActiveWindows: mainBarWindow.hasActiveWindows
                active: !root.isFullscreen

                onCurrentViewChanged: {
                    root.currentScreen = currentView === "default" ? "none" : currentView
                }

                onCloseRequested: {
                    root.currentScreen = "none"
                }
                
                onBarHoverChanged: (hovering) => {
                    mainBarWindow.barIsHovered = hovering
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
            top: workspaceBarContent.isExpanded
            right: workspaceBarContent.isExpanded
        }
        // Negative margin to counteract exclusive zone push
        margins.bottom: exclusiveZoneBar.visible ? -exclusiveZoneBar.zoneHeight : 0
        margins.left: 0

        // Window size - use -1 when expanded (anchors control size)
        implicitHeight: workspaceBarContent.isExpanded ? -1 : 60
        implicitWidth: workspaceBarContent.isExpanded ? -1 : (workspaceBarContent.implicitWidth + 20)

        WlrLayershell.layer: workspaceBarContent.isExpanded ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.namespace: "molten-left"
        WlrLayershell.keyboardFocus: workspaceBarContent.isExpanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        color: "transparent"
        
        // Mask: full window when expanded, bar area otherwise
        mask: Region {
            item: workspaceBarContent.isExpanded ? workspaceBarFullMask : workspaceBarMask
        }
        
        Item {
            id: workspaceBarFullMask
            anchors.fill: parent
        }
        
        Item {
            id: workspaceBarMask
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: workspaceBarRegionContainer.width + 20
            height: workspaceBarRegionContainer.height + 20
        }
        
        // Click outside to close
        MouseArea {
            anchors.fill: parent
            z: -1
            visible: workspaceBarContent.isExpanded
            onClicked: workspaceBarContent.closeView()
        }
        
        // Auto-reveal when workspace changes
        Connections {
            target: Root.State
            function onActiveWorkspaceChanged() {
                workspaceBarContent.showTemporarily()
            }
        }

        Item {
            id: workspaceBarRegionContainer
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 6
            anchors.bottomMargin: 2
            width: workspaceBarContent.implicitWidth
            height: workspaceBarContent.implicitHeight
            
            WorkspaceBar {
                id: workspaceBarContent
                anchors.centerIn: parent
                mode: Config.workspaceBarMode
                hasActiveWindows: mainBarWindow.hasActiveWindows
                active: !root.isFullscreen
                onOverviewRequested: State.toggleOverview()
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // STATUS BAR - Power, Toolbar, System Tray
    // ═══════════════════════════════════════════════════════════════
    PanelWindow {
        id: statusBar
        visible: !root.isFullscreen

        anchors {
            bottom: true
            right: true
            top: statusBarContent.isExpanded
            left: statusBarContent.isExpanded
        }
        // Negative margin to counteract exclusive zone push
        margins.bottom: exclusiveZoneBar.visible ? -exclusiveZoneBar.zoneHeight : 0
        margins.right: 0

        // Window size - use -1 when expanded (anchors control size)
        implicitHeight: statusBarContent.isExpanded ? -1 : 60
        implicitWidth: statusBarContent.isExpanded ? -1 : (statusBarContent.implicitWidth + 20)

        WlrLayershell.layer: statusBarContent.isExpanded ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.namespace: "molten-right"
        WlrLayershell.keyboardFocus: statusBarContent.isExpanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        color: "transparent"
        
        // Mask: full window when expanded, bar area otherwise
        mask: Region {
            item: statusBarContent.isExpanded ? statusBarFullMask : statusBarMask
        }
        
        Item {
            id: statusBarFullMask
            anchors.fill: parent
        }
        
        Item {
            id: statusBarMask
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: statusBarRegionContainer.width + 20
            height: statusBarRegionContainer.height + 20
        }
        
        // Click outside to close
        MouseArea {
            anchors.fill: parent
            z: -1
            visible: statusBarContent.isExpanded
            onClicked: statusBarContent.closeView()
        }

        Item {
            id: statusBarRegionContainer
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 6
            anchors.bottomMargin: 2
            width: statusBarContent.implicitWidth
            height: statusBarContent.implicitHeight
            
            StatusBar {
                id: statusBarContent
                anchors.centerIn: parent
                parentWindow: statusBar
                mode: Config.statusBarMode
                hasActiveWindows: mainBarWindow.hasActiveWindows
                active: !root.isFullscreen
                onPowerRequested: {
                    statusBarContent.closeView()
                    mainBarContent.openView("power")
                }
                // GNOME-like volume scroll - trigger MainBar volume overlay
                onVolumeScrollChanged: {
                    mainBarContent.showVolumeOverlay()
                }
            }
        }
    }


}
