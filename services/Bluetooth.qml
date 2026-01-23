pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Bluetooth service - Handles Bluetooth status and control via bluetoothctl
 */
Singleton {
    id: root

    // Bluetooth state
    property bool enabled: false
    property bool discovering: false
    property bool connected: false
    property int connectedDevices: 0

    // ═══════════════════════════════════════════════════════════════
    // BLUETOOTH CONTROL
    // ═══════════════════════════════════════════════════════════════

    function toggle() {
        setEnabled(!enabled)
    }

    function setEnabled(value) {
        toggleProc.command = ["bluetoothctl", "power", value ? "on" : "off"]
        toggleProc.running = true
    }

    function startDiscovery() {
        if (enabled) {
            discovering = true
            scanProc.command = ["bluetoothctl", "scan", "on"]
            scanProc.running = true
            // Stop scanning after 15 seconds
            scanTimer.restart()
        }
    }

    function stopDiscovery() {
        discovering = false
        stopScanProc.command = ["bluetoothctl", "scan", "off"]
        stopScanProc.running = true
        scanTimer.stop()
    }

    function connectDevice(address) {
        connectProc.command = ["bluetoothctl", "connect", address]
        connectProc.running = true
    }

    function disconnectDevice(address) {
        disconnectProc.command = ["bluetoothctl", "disconnect", address]
        disconnectProc.running = true
    }

    // ═══════════════════════════════════════════════════════════════
    // STATUS UPDATE
    // ═══════════════════════════════════════════════════════════════

    function updateStatus() {
        checkPowerProc.running = true
    }

    // ═══════════════════════════════════════════════════════════════
    // PROCESSES
    // ═══════════════════════════════════════════════════════════════

    Process {
        id: toggleProc
        onExited: root.updateStatus()
    }

    Process {
        id: scanProc
    }

    Process {
        id: stopScanProc
    }

    Process {
        id: connectProc
        onExited: root.updateStatus()
    }

    Process {
        id: disconnectProc
        onExited: root.updateStatus()
    }

    // Check if Bluetooth is powered on
    Process {
        id: checkPowerProc
        command: ["bash", "-c", "bluetoothctl show | grep 'Powered:' | awk '{print $2}'"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                var output = data.trim()
                root.enabled = output === "yes"
                
                if (root.enabled) {
                    checkConnectedProc.running = true
                } else {
                    root.connected = false
                    root.connectedDevices = 0
                    root.discovering = false
                }
            }
        }
    }

    // Check connected devices count
    Process {
        id: checkConnectedProc
        command: ["bash", "-c", "bluetoothctl devices Connected | wc -l"]
        stdout: SplitParser {
            onRead: (data) => {
                var output = data.trim()
                root.connectedDevices = parseInt(output) || 0
                root.connected = root.connectedDevices > 0
            }
        }
    }

    // Timers
    Timer {
        id: scanTimer
        interval: 15000
        onTriggered: root.stopDiscovery()
    }

    // Periodic refresh
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.updateStatus()
    }

    Component.onCompleted: updateStatus()
}
