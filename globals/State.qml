pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

Singleton {
    id: root

    // ═══════════════════════════════════════════════════════════════
    // WINDOW LIST TRACKING (for workspace app icons)
    // ═══════════════════════════════════════════════════════════════
    
    property var windowList: []
    property var windowByAddress: ({})
    
    function updateWindowList() {
        getClientsProc.running = true
    }
    
    // Get focused window for a specific workspace
    function getFocusedWindowForWorkspace(wsId) {
        const windowsInWorkspace = windowList.filter(w => w.workspace && w.workspace.id === wsId)
        if (windowsInWorkspace.length === 0) return null
        
        // Get the window with the lowest focusHistoryID (most recently focused)
        return windowsInWorkspace.reduce((best, win) => {
            const bestFocus = best?.focusHistoryID ?? Infinity
            const winFocus = win?.focusHistoryID ?? Infinity
            return winFocus < bestFocus ? win : best
        }, null)
    }
    
    Process {
        id: getClientsProc
        command: ["bash", "-c", "hyprctl clients -j | jq -c"]
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    root.windowList = JSON.parse(data)
                    let tempWinByAddress = {}
                    for (var i = 0; i < root.windowList.length; ++i) {
                        var win = root.windowList[i]
                        tempWinByAddress[win.address] = win
                    }
                    root.windowByAddress = tempWinByAddress
                } catch (e) {
                    console.log("Failed to parse window list:", e)
                }
            }
        }
    }
    
    // Update window list on Hyprland events
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // Skip events that don't affect window list
            if (["activewindow", "focusedmon", "monitoradded", 
                 "createworkspace", "destroyworkspace", "moveworkspace", 
                 "activespecial", "windowtitle"].includes(event.name)) return
            updateWindowList()
        }
    }
    
    Component.onCompleted: updateWindowList()

    // ═══════════════════════════════════════════════════════════════
    // HYPRLAND NATIVE INTEGRATION
    // ═══════════════════════════════════════════════════════════════

    // Active monitor
    readonly property HyprlandMonitor monitor: Hyprland.focusedMonitor

    // Active workspace ID from native Hyprland binding
    readonly property int activeWorkspace: monitor?.activeWorkspace?.id ?? 1

    // Total workspaces to show (configurable)
    property int workspaceCount: 10

    // Get list of workspace IDs that exist or should be shown
    readonly property var workspaces: {
        var ids = []
        // Always show workspaces 1 through workspaceCount
        for (var i = 1; i <= workspaceCount; i++) {
            ids.push(i)
        }
        return ids
    }

    // Check which workspaces have windows
    function isWorkspaceOccupied(wsId) {
        return Hyprland.workspaces.values.some(function(ws) {
            return ws.id === wsId && ws.windows > 0
        })
    }

    // Get occupied ranges for highlight effect
    function getOccupiedRanges() {
        var ranges = []
        var rangeStart = -1

        for (var i = 0; i < workspaceCount; i++) {
            var wsId = i + 1
            var isOccupied = isWorkspaceOccupied(wsId)

            if (isOccupied) {
                if (rangeStart === -1) {
                    rangeStart = i
                }
            } else {
                if (rangeStart !== -1) {
                    ranges.push({ start: rangeStart, end: i - 1 })
                    rangeStart = -1
                }
            }
        }

        if (rangeStart !== -1) {
            ranges.push({ start: rangeStart, end: workspaceCount - 1 })
        }

        return ranges
    }

    // Window state - true when there's an active (focused) window
    // Using the same approach as Ambxst: check ToplevelManager.activeToplevel.activated
    readonly property bool hasActiveWindows: {
        var toplevel = ToplevelManager.activeToplevel
        return toplevel ? toplevel.activated : false
    }

    // Fullscreen detection from active toplevel
    readonly property bool isFullscreen: {
        var toplevel = ToplevelManager.activeToplevel
        if (!toplevel) return false
        return toplevel.fullscreen
    }

    // Media state (MPRIS)
    property bool mediaPlaying: false
    property string mediaTitle: ""
    property string mediaArtist: ""

    // Notifications - now delegated to Notifications service
    // Keep these for backward compatibility but they're deprecated
    property alias notifications: root._notificationsDeprecated
    property var _notificationsDeprecated: []
    property alias doNotDisturb: root._dndDeprecated
    property bool _dndDeprecated: false

    // System
    property real volume: 0.5
    property real brightness: 0.8
    property bool wifiEnabled: true
    property bool bluetoothEnabled: false
    property bool caffeineMode: false
    property bool gameMode: false

    // Weather & Events
    property string weatherTemp: "22°"
    property string weatherIcon: "weather-clear"
    property var upcomingEvents: []
    property bool eventSoon: false

    // Animation duration
    property int animDuration: 300

    // ═══════════════════════════════════════════════════════════════
    // HYPRLAND DISPATCH FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    function switchWorkspace(num) {
        Hyprland.dispatch("workspace " + num)
    }

    function switchWorkspaceRelative(delta) {
        if (delta > 0) {
            Hyprland.dispatch("workspace r+1")
        } else {
            Hyprland.dispatch("workspace r-1")
        }
    }

    function toggleOverview() {
        Hyprland.dispatch("overview:toggle")
    }

    // Deprecated notification functions - use Notifications service directly
    function addNotification(summary, body, icon, urgency) {
        console.warn("State.addNotification is deprecated. Notifications are now handled by the Notifications service.")
    }

    function clearNotifications() {
        console.warn("State.clearNotifications is deprecated. Use Notifications.discardAllNotifications() instead.")
    }

    function dismissNotification(id) {
        console.warn("State.dismissNotification is deprecated. Use Notifications.discardNotification(id) instead.")
    }

    // Media controls
    function mediaPlayPause() {
        mediaPlayPauseProc.running = true
    }
    Process {
        id: mediaPlayPauseProc
        command: ["playerctl", "play-pause"]
    }

    function mediaNext() {
        mediaNextProc.running = true
    }
    Process {
        id: mediaNextProc
        command: ["playerctl", "next"]
    }

    function mediaPrevious() {
        mediaPreviousProc.running = true
    }
    Process {
        id: mediaPreviousProc
        command: ["playerctl", "previous"]
    }

    // Poll media state
    Process {
        id: mediaStatusProc
        command: ["playerctl", "status"]
        onExited: {
            if (stdout !== null && stdout !== undefined) {
                root.mediaPlaying = (stdout.trim() === "Playing")
            } else {
                root.mediaPlaying = false
            }
        }
    }

    Process {
        id: mediaTitleProc
        command: ["playerctl", "metadata", "title"]
        onExited: {
            root.mediaTitle = (stdout !== null && stdout !== undefined) ? stdout.trim() : ""
        }
    }

    Process {
        id: mediaArtistProc
        command: ["playerctl", "metadata", "artist"]
        onExited: {
            root.mediaArtist = (stdout !== null && stdout !== undefined) ? stdout.trim() : ""
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            mediaStatusProc.running = true
            mediaTitleProc.running = true
            mediaArtistProc.running = true
        }
    }

    // Power actions
    function powerLock() {
        lockProc.running = true
    }
    Process {
        id: lockProc
        command: ["hyprlock"]
    }

    function powerSuspend() {
        suspendProc.running = true
    }
    Process {
        id: suspendProc
        command: ["systemctl", "suspend"]
    }

    function powerReboot() {
        rebootProc.running = true
    }
    Process {
        id: rebootProc
        command: ["systemctl", "reboot"]
    }

    function powerShutdown() {
        shutdownProc.running = true
    }
    Process {
        id: shutdownProc
        command: ["systemctl", "poweroff"]
    }

    function powerLogout() {
        logoutProc.running = true
    }
    Process {
        id: logoutProc
        command: ["hyprctl", "dispatch", "exit"]
    }

    // App launching
    function launchApp(desktopFile) {
        launchProc.command = ["gtk-launch", desktopFile]
        launchProc.running = true
    }
    Process {
        id: launchProc
    }
}
