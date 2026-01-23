pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Clipboard service - Manages clipboard history using cliphist
 */
Singleton {
    id: root

    // Clipboard history
    property var history: []
    property bool ready: false
    property string error: ""

    // Currently selected item for paste
    property var selectedItem: null

    // ═══════════════════════════════════════════════════════════════
    // CLIPBOARD OPERATIONS
    // ═══════════════════════════════════════════════════════════════

    function refresh() {
        listProc.running = true
    }

    function paste(id) {
        pasteProc.command = ["bash", "-c", "cliphist decode " + id + " | wl-copy"]
        pasteProc.running = true
    }

    function remove(id) {
        removeProc.command = ["bash", "-c", "cliphist delete-query " + id]
        removeProc.running = true
        // Refresh after deletion
        removeRefreshTimer.start()
    }

    function clear() {
        clearProc.running = true
        // Refresh after clearing
        clearRefreshTimer.start()
    }

    // ═══════════════════════════════════════════════════════════════
    // PROCESSES
    // ═══════════════════════════════════════════════════════════════

    // List clipboard history
    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: (data) => {
                var lines = data.trim().split("\n")
                var items = []
                for (var i = 0; i < lines.length && i < 100; i++) {
                    var line = lines[i]
                    if (line.trim() === "") continue
                    
                    // Format: "id\tpreview"
                    var tabIndex = line.indexOf("\t")
                    if (tabIndex > 0) {
                        var id = line.substring(0, tabIndex)
                        var preview = line.substring(tabIndex + 1)
                        
                        // Detect if it's an image
                        var isImage = preview.startsWith("[[ binary data")
                        
                        items.push({
                            id: id,
                            preview: preview,
                            isImage: isImage,
                            timestamp: Date.now() - i  // For sorting
                        })
                    }
                }
                root.history = items
                root.ready = true
            }
        }
        stderr: SplitParser {
            onRead: (line) => {
                if (line.includes("no such file") || line.includes("not found")) {
                    root.error = "cliphist not running. Start it with: cliphist store"
                }
            }
        }
    }

    Process {
        id: pasteProc
    }

    Process {
        id: removeProc
    }

    Process {
        id: clearProc
        command: ["cliphist", "wipe"]
    }

    // Timers for refresh after operations
    Timer {
        id: removeRefreshTimer
        interval: 100
        onTriggered: root.refresh()
    }

    Timer {
        id: clearRefreshTimer
        interval: 100
        onTriggered: root.refresh()
    }

    // Initial load only - no periodic refresh to avoid scroll reset
    Component.onCompleted: refresh()

    // Watch for clipboard changes using wl-paste --watch
    Process {
        id: clipboardWatcher
        command: ["wl-paste", "--watch", "echo", "changed"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (data) => {
                if (data.trim() === "changed") {
                    root.refresh()
                }
            }
        }
    }
}
