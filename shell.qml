//@ pragma UseQApplication

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import "components"
import "components/popups"
import "config"
import "globals" as Root
import "globals"
import "services"

ShellRoot {
    id: root

    // Current screen state (synced with main bar)
    property string currentScreen: "none"
    
    // ═══════════════════════════════════════════════════════════════
    // ADAPTIVE COLORS SERVICE - Screen sampling for dynamic colors
    // ═══════════════════════════════════════════════════════════════
    Process {
        id: adaptiveColorsService
        command: [Quickshell.workingDirectory + "/scripts/adaptive_colors.py"]
        running: true
        
        onRunningChanged: {
            if (!running) {
                // Restart if it crashes
                restartTimer.start()
            }
        }
    }
    
    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: adaptiveColorsService.running = true
    }
    
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

        // Any popup active helper
        readonly property bool anyPopupActive: mainBarContent.toolbarPopupActive || mainBarContent.livePopupActive || mainBarContent.appPopupActive

        WlrLayershell.keyboardFocus: (mainBarContent.isExpanded || anyPopupActive) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        // Note: Can't use exclusiveZone here - window is full-screen for click handling
        // Side bars handle the exclusive zone reservation

        // Mask: full window when expanded or popup active, full-width bottom zone otherwise
        mask: Region {
            item: (mainBarContent.isExpanded || mainBarWindow.anyPopupActive) ? fullWindowMask : bottomHoverMask
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
            visible: mainBarContent.isExpanded || mainBarWindow.anyPopupActive
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
                
                // Screen dimensions for positioning
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
            
            // Toolbar Popup - Floats above the bar, expands from right
            ToolbarPopup {
                id: toolbarPopup
                
                // Position above bar, aligned to right side with larger margin
                anchors.bottom: mainBarContent.top
                anchors.bottomMargin: 6
                anchors.right: mainBarContent.right
                
                // Screen position for adaptive colors
                screenX: Math.round((mainBarWindow.width - toolbarPopup.width) / 2 + (mainBarContent.width / 2 - toolbarPopup.width / 2))
                screenY: Math.round(mainBarWindow.height - mainBarContent.height - 48 - toolbarPopup.height)
                
                // Show when toolbar is activated
                show: mainBarContent.toolbarPopupActive
                
                onCloseRequested: mainBarContent.closeView()
            }

            // Live Popup - Floats above the bar, expands from left
            LivePopup {
                id: livePopup

                anchors.bottom: mainBarContent.top
                anchors.bottomMargin: 6
                anchors.left: mainBarContent.left

                screenX: Math.round(mainBarRegionContainer.x + mainBarContent.x)
                screenY: Math.round(mainBarWindow.height - mainBarContent.height - 48 - livePopup.height)

                show: mainBarContent.livePopupActive

                onCloseRequested: mainBarContent.closeView()
            }

            // App Launcher Popup - Floats above the bar, expands from center
            AppPopup {
                id: appPopup

                anchors.bottom: mainBarContent.top
                anchors.bottomMargin: 6
                anchors.horizontalCenter: mainBarContent.horizontalCenter

                screenX: Math.round((mainBarWindow.width - appPopup.width) / 2)
                screenY: Math.round(mainBarWindow.height - mainBarContent.height - 48 - appPopup.height)

                show: mainBarContent.appPopupActive

                onCloseRequested: mainBarContent.closeView()
            }
        }
    }
}