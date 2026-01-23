pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    signal screenshotCaptured(string path)
    signal errorOccurred(string message)

    property string screenshotsDir: ""
    property string finalPath: ""
    
    // Capture modes: "area", "screen", "window"
    property string captureMode: "area"
    
    // Pending screenshot request (waits for UI to close)
    property bool pendingCapture: false
    property string pendingMode: "area"

    // Process to resolve XDG_PICTURES_DIR
    property Process xdgProcess: Process {
        command: ["bash", "-c", "xdg-user-dir PICTURES"]
        stdout: SplitParser {
            onRead: data => {
                var dir = data.trim()
                if (dir === "") {
                    dir = Quickshell.env("HOME") + "/Pictures"
                }
                root.screenshotsDir = dir + "/Screenshots"
                root.ensureDirProcess.running = true
            }
        }
        running: true
    }

    property Process ensureDirProcess: Process {
        command: ["mkdir", "-p", root.screenshotsDir]
    }

    // Screenshot process (area selection with hyprshot)
    property Process areaScreenshotProc: Process {
        command: ["hyprshot", "-m", "region", "--clipboard-only"]
        onExited: exitCode => {
            root.pendingCapture = false
            if (exitCode === 0) {
                root.screenshotCaptured(root.finalPath)
            } else {
                root.errorOccurred("Screenshot cancelled or failed")
            }
        }
    }
    
    // Full screen capture
    property Process screenScreenshotProc: Process {
        command: ["hyprshot", "-m", "output", "--clipboard-only"]
        onExited: exitCode => {
            root.pendingCapture = false
            if (exitCode === 0) {
                root.screenshotCaptured(root.finalPath)
            } else {
                root.errorOccurred("Screenshot failed")
            }
        }
    }
    
    // Active window capture
    property Process windowScreenshotProc: Process {
        command: ["hyprshot", "-m", "window", "--clipboard-only"]
        onExited: exitCode => {
            root.pendingCapture = false
            if (exitCode === 0) {
                root.screenshotCaptured(root.finalPath)
            } else {
                root.errorOccurred("Screenshot failed")
            }
        }
    }

    // Timer to delay capture (allows UI to close first)
    property Timer captureDelayTimer: Timer {
        interval: 300
        onTriggered: {
            root.executeCapture()
        }
    }

    // Request a screenshot - this should be called after closing UI
    // mode: "area", "screen", "window"
    function capture(mode) {
        pendingMode = mode || "area"
        pendingCapture = true
        captureDelayTimer.start()
    }
    
    // Immediately capture without delay (for keybind use when no UI is open)
    function captureNow(mode) {
        pendingMode = mode || "area"
        executeCapture()
    }
    
    // Internal: execute the actual capture
    function executeCapture() {
        switch (pendingMode) {
            case "screen":
                screenScreenshotProc.running = true
                break
            case "window":
                windowScreenshotProc.running = true
                break
            case "area":
            default:
                areaScreenshotProc.running = true
                break
        }
    }

    // Screen recording
    property Process screenRecordProc: Process {
        command: ["bash", "-c", "wf-recorder -g \"$(slurp)\" -f ~/Videos/recording-$(date +%Y%m%d-%H%M%S).mp4"]
    }
    
    function startRecording() {
        screenRecordProc.running = true
    }

    // Color picker
    property Process colorPickerProc: Process {
        command: ["bash", "-c", "hyprpicker -a"]
    }
    
    function pickColor() {
        colorPickerProc.running = true
    }

    // OCR
    property Process ocrProc: Process {
        command: ["bash", "-c", "grim -g \"$(slurp)\" - | tesseract stdin stdout | wl-copy && notify-send 'OCR' 'Text copied to clipboard'"]
    }
    
    function captureOCR() {
        ocrProc.running = true
    }

    // Open screenshots folder
    property Process openFolderProc: Process {
        command: ["xdg-open", root.screenshotsDir]
    }

    function openScreenshotsFolder() {
        if (root.screenshotsDir === "") {
            openFolderProc.command = ["xdg-open", Quickshell.env("HOME") + "/Pictures/Screenshots"]
        }
        openFolderProc.running = true
    }
}
