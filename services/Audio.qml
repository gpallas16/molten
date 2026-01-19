pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

/**
 * Audio service wrapper for Pipewire - based on Ambxst
 */
Singleton {
    id: root

    property bool ready: Pipewire.defaultAudioSink?.ready ?? false
    property PwNode sink: Pipewire.defaultAudioSink
    property PwNode source: Pipewire.defaultAudioSource
    
    // Current volume (0-1 range)
    property real volume: sink?.audio?.volume ?? 0
    property bool muted: sink?.audio?.muted ?? false
    
    // Microphone
    property real micVolume: source?.audio?.volume ?? 0
    property bool micMuted: source?.audio?.muted ?? false

    // Track nodes
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    // ═══════════════════════════════════════════════════════════════
    // DEVICE ENUMERATION
    // ═══════════════════════════════════════════════════════════════
    
    // Helper to get friendly device name
    function friendlyDeviceName(node) {
        return (node?.nickname || node?.description || "Unknown")
    }

    // Filter functions for nodes
    function correctType(node, isSink) {
        return (node?.isSink === isSink) && node?.audio
    }

    function appNodes(isSink) {
        return Pipewire.nodes.values.filter((node) => {
            return root.correctType(node, isSink) && node.isStream
        })
    }

    function devices(isSink) {
        return Pipewire.nodes.values.filter(node => {
            return root.correctType(node, isSink) && !node.isStream
        })
    }

    // Filtered lists for output and input DEVICES
    readonly property list<var> outputDevices: root.devices(true)
    readonly property list<var> inputDevices: root.devices(false)

    // Filtered lists for output and input APP STREAMS
    readonly property list<var> outputAppNodes: root.appNodes(true)
    readonly property list<var> inputAppNodes: root.appNodes(false)

    // ═══════════════════════════════════════════════════════════════
    // DEVICE SWITCHING
    // ═══════════════════════════════════════════════════════════════
    
    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node
    }

    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node
    }

    // ═══════════════════════════════════════════════════════════════
    // VOLUME CONTROL
    // ═══════════════════════════════════════════════════════════════

    function setVolume(vol) {
        if (sink?.audio) {
            sink.audio.volume = Math.max(0, Math.min(1, vol))
        }
    }

    function toggleMute() {
        if (sink?.audio) {
            sink.audio.muted = !sink.audio.muted
        }
    }

    function setMicVolume(vol) {
        if (source?.audio) {
            source.audio.volume = Math.max(0, Math.min(1, vol))
        }
    }

    function toggleMicMute() {
        if (source?.audio) {
            source.audio.muted = !source.audio.muted
        }
    }

    function incrementVolume() {
        if (sink?.audio) {
            sink.audio.volume = Math.min(1, sink.audio.volume + 0.05)
        }
    }

    function decrementVolume() {
        if (sink?.audio) {
            sink.audio.volume = Math.max(0, sink.audio.volume - 0.05)
        }
    }
}
