pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Network service - Handles WiFi status and control via nmcli
 */
Singleton {
    id: root

    // WiFi state
    property bool wifiEnabled: false
    property bool wifiConnected: false
    property string wifiStatus: "disconnected"  // "connected", "connecting", "disconnected", "disabled"
    property string networkName: ""
    property int networkStrength: 0
    
    // Ethernet state
    property bool ethernetConnected: false

    // ═══════════════════════════════════════════════════════════════
    // WIFI CONTROL
    // ═══════════════════════════════════════════════════════════════

    function toggleWifi() {
        enableWifi(!wifiEnabled)
    }

    function enableWifi(enabled) {
        var cmd = enabled ? "on" : "off"
        enableWifiProc.command = ["nmcli", "radio", "wifi", cmd]
        enableWifiProc.running = true
    }

    function rescanWifi() {
        rescanProc.running = true
    }

    // ═══════════════════════════════════════════════════════════════
    // STATUS UPDATE
    // ═══════════════════════════════════════════════════════════════

    function update() {
        wifiStatusProc.running = true
        connectionStatusProc.running = true
        networkNameProc.running = true
        networkStrengthProc.running = true
    }

    // ═══════════════════════════════════════════════════════════════
    // PROCESSES
    // ═══════════════════════════════════════════════════════════════

    Process {
        id: enableWifiProc
        onExited: root.update()
    }

    Process {
        id: rescanProc
        command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]
        onExited: root.update()
    }

    // Check if WiFi radio is enabled
    Process {
        id: wifiStatusProc
        command: ["nmcli", "radio", "wifi"]
        running: true
        environment: ({ LANG: "C", LC_ALL: "C" })
        stdout: SplitParser {
            onRead: (data) => {
                root.wifiEnabled = data.trim() === "enabled"
                if (!root.wifiEnabled) {
                    root.wifiStatus = "disabled"
                }
            }
        }
    }

    // Check connection status
    Process {
        id: connectionStatusProc
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE d status && nmcli -t -f CONNECTIVITY g"]
        running: true
        property string buffer: ""
        stdout: SplitParser {
            onRead: (data) => {
                connectionStatusProc.buffer += data + "\n"
            }
        }
        onExited: {
            var lines = buffer.trim().split('\n')
            buffer = ""
            
            var connectivity = lines.pop()
            var hasEthernet = false
            var hasWifi = false
            var status = "disconnected"
            
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                if (line.includes("ethernet") && line.includes("connected")) {
                    hasEthernet = true
                } else if (line.includes("wifi:")) {
                    if (line.includes("disconnected")) {
                        status = "disconnected"
                    } else if (line.includes("connected")) {
                        hasWifi = true
                        status = "connected"
                        if (connectivity === "limited") {
                            status = "limited"
                        }
                    } else if (line.includes("connecting")) {
                        status = "connecting"
                    } else if (line.includes("unavailable")) {
                        status = "disabled"
                    }
                }
            }
            
            root.ethernetConnected = hasEthernet
            root.wifiConnected = hasWifi
            root.wifiStatus = status
        }
    }

    // Get active connection name
    Process {
        id: networkNameProc
        command: ["sh", "-c", "nmcli -t -f NAME c show --active | head -1"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                root.networkName = data.trim()
            }
        }
    }

    // Get WiFi signal strength
    Process {
        id: networkStrengthProc
        command: ["sh", "-c", "nmcli -f IN-USE,SIGNAL,SSID device wifi | awk '/^\\*/{if (NR!=1) {print $2}}'"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                root.networkStrength = parseInt(data.trim()) || 0
            }
        }
    }

    // Monitor network changes
    Process {
        id: monitorProc
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: root.update()
        }
    }

    // Periodic refresh
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.update()
    }

    Component.onCompleted: update()
}
