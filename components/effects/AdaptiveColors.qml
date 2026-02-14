import QtQuick
import Quickshell
import Quickshell.Io

/**
 * AdaptiveColors - Dynamic screen sampling for adaptive text colors
 * 
 * Registers with the adaptive_colors.py service by writing to a shared
 * regions file. The service captures screen content and writes results
 * to an output file which this component watches.
 * 
 * Usage:
 *   AdaptiveColors {
 *       id: adaptiveColors
 *       regionId: "myElement"
 *       sampleX: 100
 *       sampleY: 900  
 *       sampleWidth: 400
 *       sampleHeight: 60
 *   }
 */
Item {
    id: root
    
    // Region identifier (for multiple samplers)
    property string regionId: "default"
    
    // Sample region coordinates (screen-absolute)
    property int sampleX: 0
    property int sampleY: 0
    property int sampleWidth: 400
    property int sampleHeight: 60
    
    // Whether this component is active
    property bool active: true
    
    // Output: whether the background is dark (content should be light)
    property bool backgroundIsDark: true
    
    // Output: adaptive colors based on background
    property color textColor: backgroundIsDark ? "#ffffff" : "#000000"
    property color textColorSecondary: backgroundIsDark ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(0, 0, 0, 0.6)
    property color iconColor: backgroundIsDark ? "#ffffff" : "#000000"
    property color subtleTextColor: backgroundIsDark ? Qt.rgba(1, 1, 1, 0.7) : Qt.rgba(0, 0, 0, 0.7)
    
    // Smooth transition when colors change
    Behavior on textColor { ColorAnimation { duration: 200 } }
    Behavior on textColorSecondary { ColorAnimation { duration: 200 } }
    Behavior on iconColor { ColorAnimation { duration: 200 } }
    Behavior on subtleTextColor { ColorAnimation { duration: 200 } }
    
    // Debouncing for stability
    property bool _pendingDark: true
    property int _stableCount: 0
    readonly property int _requiredStable: 2
    
    // File paths
    readonly property string regionsFile: "/tmp/molten-adaptive-regions.json"
    readonly property string resultsFile: "/tmp/molten-adaptive-colors.json"
    
    // Register this region with the service
    Process {
        id: registerProcess
        command: ["python3", "-c",
            "import json,os;" +
            "f='" + root.regionsFile + "';" +
            "d=json.load(open(f)) if os.path.exists(f) else {};" +
            "d['" + root.regionId + "']={'x':" + root.sampleX + ",'y':" + root.sampleY + ",'w':" + root.sampleWidth + ",'h':" + root.sampleHeight + "};" +
            "open(f,'w').write(json.dumps(d))"
        ]
    }
    
    // Unregister when destroyed
    Process {
        id: unregisterProcess
        command: ["python3", "-c",
            "import json,os;" +
            "f='" + root.regionsFile + "';" +
            "d=json.load(open(f)) if os.path.exists(f) else {};" +
            "d.pop('" + root.regionId + "',None);" +
            "open(f,'w').write(json.dumps(d))"
        ]
    }
    
    // Watch results file for updates from service
    FileView {
        id: resultsWatcher
        path: root.resultsFile
        watchChanges: root.active
        
        onFileChanged: reload()
        
        onLoaded: {
            if (!root.active) return
            try {
                var data = JSON.parse(text())
                var regionData = data[root.regionId]
                if (regionData && regionData.isDark !== undefined) {
                    var isDark = regionData.isDark
                    
                    // Debounce state changes
                    if (isDark === root._pendingDark) {
                        root._stableCount++
                        if (root._stableCount >= root._requiredStable && 
                            root.backgroundIsDark !== isDark) {
                            root.backgroundIsDark = isDark
                        }
                    } else {
                        root._pendingDark = isDark
                        root._stableCount = 0
                    }
                }
            } catch (e) {
                // Parse error - ignore
            }
        }
    }
    
    // Register when region changes
    onSampleXChanged: if (active) registerRegion()
    onSampleYChanged: if (active) registerRegion()
    onSampleWidthChanged: if (active) registerRegion()
    onSampleHeightChanged: if (active) registerRegion()
    onActiveChanged: {
        if (active) registerRegion()
        else unregisterRegion()
    }
    
    function registerRegion() {
        if (sampleWidth > 0 && sampleHeight > 0 && !registerProcess.running) {
            registerProcess.running = true
        }
    }
    
    function unregisterRegion() {
        unregisterProcess.running = true
    }
    
    // Initial registration
    Component.onCompleted: {
        if (active && sampleWidth > 0 && sampleHeight > 0) {
            registerRegion()
        }
    }
    
    // Cleanup on destruction
    Component.onDestruction: {
        unregisterRegion()
    }
}

