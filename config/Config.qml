pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Config - Global configuration for Molten shell
 * 
 * External config file: ~/.config/molten/config.json
 * 
 * Bar modes:
 * - "floating": Always visible with full UI
 * - "discrete": Always shows compact UI, hides on hover
 * - "hidden": Hidden until edge hit, then shows as floating
 * - "dynamic": No windows = floating, active windows = discrete behavior
 */
Singleton {
    id: root
    
    // ═══════════════════════════════════════════════════════════════
    // CONFIG PATHS
    // ═══════════════════════════════════════════════════════════════
    
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/molten"
    readonly property string configPath: configDir + "/config.json"
    
    // ═══════════════════════════════════════════════════════════════
    // BAR MODES
    // ═══════════════════════════════════════════════════════════════
    
    /** Workspace bar (left) - launcher, overview, workspaces */
    readonly property string workspaceBarMode: "dynamic"
    
    /** Main bar (center) - dynamic island notch */
    readonly property string mainBarMode: "dynamic"
    
    /** Status bar (right) - tray, status, power */
    readonly property string statusBarMode: "dynamic"
    
    // ═══════════════════════════════════════════════════════════════
    // WALLPAPER SETTINGS
    // ═══════════════════════════════════════════════════════════════
    
    /** Directory containing wallpapers */
    property string wallpapersPath: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    
    /** Currently active wallpaper (full path) */
    property string activeWallpaper: ""
    
    /** Signal emitted when wallpaper changes */
    signal wallpaperChanged(string path)
    
    // ═══════════════════════════════════════════════════════════════
    // CONFIG FILE HANDLING
    // ═══════════════════════════════════════════════════════════════
    
    property bool configReady: false
    
    // Initialize config directory and load config
    property Process initProcess: Process {
        running: true
        command: ["bash", "-c", `
            mkdir -p "${root.configDir}"
            if [ ! -f "${root.configPath}" ]; then
                echo '{"wallpapersPath": "'$HOME'/Pictures/Wallpapers", "activeWallpaper": ""}' > "${root.configPath}"
            fi
            cat "${root.configPath}"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseConfig(text)
                // Enable file watcher after init is complete
                configWatcher.path = root.configPath
            }
        }
    }
    
    // Watch config file for changes (path set after init)
    property FileView configWatcher: FileView {
        path: ""
        onTextChanged: {
            if (text && root.configReady) {
                root.parseConfig(text)
            }
        }
    }
    
    // Parse JSON config
    function parseConfig(jsonStr) {
        try {
            var config = JSON.parse(jsonStr)
            
            if (config.wallpapersPath) {
                wallpapersPath = config.wallpapersPath
            }
            
            if (config.activeWallpaper) {
                var oldWallpaper = activeWallpaper
                activeWallpaper = config.activeWallpaper
                if (oldWallpaper !== activeWallpaper) {
                    wallpaperChanged(activeWallpaper)
                }
            }
            
            configReady = true
        } catch (e) {
            console.warn("Config: Failed to parse config.json:", e.message)
            configReady = true
        }
    }
    
    // Save current config to file
    function saveConfig() {
        var config = {
            wallpapersPath: wallpapersPath,
            activeWallpaper: activeWallpaper
        }
        saveProcess.command = ["bash", "-c", `echo '${JSON.stringify(config, null, 2)}' > "${configPath}"`]
        saveProcess.running = true
    }
    
    property Process saveProcess: Process {}
    
    // Set active wallpaper and save
    function setWallpaper(path) {
        var oldWallpaper = activeWallpaper
        activeWallpaper = path
        saveConfig()
        if (oldWallpaper !== path) {
            wallpaperChanged(path)
        }
    }
}
