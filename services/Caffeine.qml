pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * Caffeine service - Inhibits system idle/suspend using Wayland IdleInhibitor
 * 
 * When enabled, prevents the system from going idle or suspending.
 * Uses the Wayland IdleInhibitor protocol.
 */
Singleton {
    id: root

    // Whether caffeine mode (idle inhibit) is enabled
    property bool enabled: false

    function toggle() {
        enabled = !enabled
    }

    // Hidden window with IdleInhibitor
    IdleInhibitor {
        id: idleInhibitor
        enabled: root.enabled
        window: PanelWindow {
            id: inhibitorWindow
            visible: root.enabled
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            anchors {
                right: true
                bottom: true
            }
            // Empty mask so the window is invisible but still exists
            mask: Region {
                item: null
            }
        }
    }
}
