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
            
            switch (action) {
                case "launcher":
                    mainBarContent.openView("launcher")
                    break
                case "notifications":
                    // Notifications merged into live screen
                    mainBarContent.openView("live")
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
                case "clipboard":
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
            
            // Show bar temporarily on workspace change
            if (event.name === "workspace") {
                mainBarContent.showTemporarily()
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
        visible: Config.mainBarMode !== "hidden"
        
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

        // Mask: full window when expanded, full-width bottom zone otherwise
        mask: Region {
            item: mainBarContent.isExpanded ? fullWindowMask : bottomHoverMask
        }

        // Full window mask for catching outside clicks when expanded
        Item {
            id: fullWindowMask
            anchors.fill: parent
        }
        
        // Full-width bottom hover mask - spans entire width for hover detection
        Item {
            id: bottomHoverMask
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: mainBarContent.compactMode ? 40 : mainBarContent.implicitHeight + mainBarContent.barMargin + 20
        }

        // Click outside expanded main bar to close (full window area)
        MouseArea {
            anchors.fill: parent
            z: -1
            visible: mainBarContent.isExpanded
            onClicked: mainBarContent.closeView()
        }

        // Full-width bottom hover zone for bar reveal
        // Spans entire screen width at the same height as the bar
        MouseArea {
            id: bottomHoverZone
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: mainBarContent.compactMode ? 40 : mainBarContent.implicitHeight + mainBarContent.barMargin
            hoverEnabled: true
            propagateComposedEvents: true
            acceptedButtons: Qt.NoButton
            z: -1  // Below the bar itself
            
            onContainsMouseChanged: {
                mainBarWindow.barIsHovered = containsMouse
            }
        }

        // Container for the main bar region (for masking when collapsed)
        Item {
            id: mainBarRegionContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            // Position from MainBar's barShape - single source of truth
            anchors.bottomMargin: mainBarContent.barMargin
            width: mainBarContent.implicitWidth
            height: mainBarContent.implicitHeight
            
            Behavior on anchors.bottomMargin {
                NumberAnimation { duration: 300; easing.type: Easing.OutQuart }
            }

            MainBar {
                id: mainBarContent
                anchors.centerIn: parent
                parentWindow: mainBarWindow
                
                // Screen dimensions for GlassBackdrop positioning
                screenWidth: mainBarWindow.width
                screenHeight: mainBarWindow.height
                
                // Behavior inputs - MainBar now has its own BarBehavior
                mode: Config.mainBarMode
                hasActiveWindows: mainBarWindow.hasActiveWindows
                active: !root.isFullscreen
                
                // External hover from bottom zone
                externalHover: mainBarWindow.barIsHovered

                onCurrentViewChanged: {
                    root.currentScreen = currentView === "default" ? "none" : currentView
                }

                onCloseRequested: {
                    root.currentScreen = "none"
                }
                
                onBarHoverChanged: (hovering) => {
                    // No longer needed - using externalHover instead
                }
            }
        }
    }
}
