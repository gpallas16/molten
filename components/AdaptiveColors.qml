import QtQuick
import Quickshell.Io

// Reads adaptive color data from the liquid glass plugin
// The plugin calculates background luminance and writes to a JSON file
Item {
    id: root
    
    // Which region this component represents (left, right, notch)
    property string region: "notch"
    
    // Output: whether the background is dark (content should be light)
    property bool backgroundIsDark: true
    
    // Output: adaptive colors based on background
    property color textColor: backgroundIsDark ? "#ffffff" : "#000000"
    property color textColorSecondary: backgroundIsDark ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(0, 0, 0, 0.6)
    property color iconColor: backgroundIsDark ? "#ffffff" : "#000000"
    property color subtleTextColor: backgroundIsDark ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(0, 0, 0, 0.7)
    
    // Smooth transition when colors change
    Behavior on textColor { ColorAnimation { duration: 150 } }
    Behavior on textColorSecondary { ColorAnimation { duration: 150 } }
    Behavior on iconColor { ColorAnimation { duration: 150 } }
    Behavior on subtleTextColor { ColorAnimation { duration: 150 } }
    
    // File watcher for adaptive color data (written by liquid glass plugin)
    FileView {
        id: colorDataFile
        path: "/tmp/molten-adaptive-colors.json"
        watchChanges: true
        
        onFileChanged: reload()
        
        onLoaded: {
            try {
                var data = JSON.parse(text())
                if (data[root.region]) {
                    root.backgroundIsDark = data[root.region].isDark
                }
            } catch (e) {
                // File not ready or parse error
            }
        }
    }
    
    // Also poll periodically as backup
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: colorDataFile.reload()
    }
    
    Component.onCompleted: colorDataFile.reload()
}
