pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Brightness service - Handles screen brightness control
 * Similar behavior to Audio service for volume
 */
Singleton {
    id: root

    // Current brightness (0-1 range)
    property real brightness: 0.8
    property bool ready: true

    // Device name (detected from brightnessctl)
    property string device: ""
    property int maxBrightness: 100

    // ═══════════════════════════════════════════════════════════════
    // BRIGHTNESS CONTROL
    // ═══════════════════════════════════════════════════════════════

    function setBrightness(val) {
        var clamped = Math.max(0.05, Math.min(1, val))  // Min 5% to avoid black screen
        root.brightness = clamped
        setBrightnessProc.command = ["brightnessctl", "set", Math.round(clamped * 100) + "%"]
        setBrightnessProc.running = true
    }

    function incrementBrightness() {
        setBrightness(brightness + 0.05)
    }

    function decrementBrightness() {
        setBrightness(brightness - 0.05)
    }

    // ═══════════════════════════════════════════════════════════════
    // PROCESSES
    // ═══════════════════════════════════════════════════════════════

    Process {
        id: setBrightnessProc
    }

    // Get current brightness on startup
    Process {
        id: getBrightnessProc
        command: ["bash", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%'"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                var percent = parseInt(data.trim())
                if (!isNaN(percent)) {
                    root.brightness = percent / 100
                }
            }
        }
    }

    // Get max brightness
    Process {
        id: getMaxBrightnessProc
        command: ["brightnessctl", "max"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                var max = parseInt(data.trim())
                if (!isNaN(max)) {
                    root.maxBrightness = max
                }
            }
        }
    }

    // Refresh brightness periodically (in case changed externally)
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: getBrightnessProc.running = true
    }
    
    // Function to force refresh (called when brightness overlay is shown)
    function refresh() {
        getBrightnessProc.running = true
    }
}
