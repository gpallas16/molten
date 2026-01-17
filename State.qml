pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

Singleton {
    id: root

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

    // Window state from Hyprland
    readonly property bool hasActiveWindows: {
        var focusedWs = monitor?.activeWorkspace
        if (!focusedWs) return false
        return focusedWs.windows > 0
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

    // Notifications
    property var notifications: []
    property bool doNotDisturb: false

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

    function addNotification(summary, body, icon, urgency) {
        if (doNotDisturb && urgency < 2) return
        
        var newNotif = {
            id: Date.now(),
            summary: summary,
            body: body,
            icon: icon,
            urgency: urgency,
            timestamp: new Date()
        }
        
        var newList = notifications.slice()
        newList.unshift(newNotif)
        
        if (newList.length > 50) {
            newList.pop()
        }
        
        notifications = newList
    }

    function clearNotifications() {
        notifications = []
    }

    function dismissNotification(id) {
        notifications = notifications.filter(function(n) { return n.id !== id })
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
