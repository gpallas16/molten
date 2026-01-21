import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../globals"
import "../effects"
import "../behavior"
import "../transforms"
import "../widgets"

Item {
    id: root
    implicitWidth: barTransform.animatedWidth
    implicitHeight: barTransform.animatedHeight

    signal launcherRequested()
    signal overviewRequested()
    signal barHoverChanged(bool hovering)

    // ═══════════════════════════════════════════════════════════════
    // BEHAVIOR MODE - Controls auto-hide behavior
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * Behavior mode for the bar
     * @type {string} "floating" | "hidden" | "dynamic"
     * - floating: Always visible
     * - hidden: Hidden until edge hit or hover
     * - dynamic: Shows on hover/activity, auto-hides
     */
    property string mode: "dynamic"
    
    /** Whether there are active windows (affects dynamic mode) */
    property bool hasActiveWindows: false
    
    /** Edge hit trigger (e.g., mouse at screen edge) */
    property bool edgeHit: false
    
    // Internal hover tracking
    property bool _realHover: false
    
    /**
     * Temporarily show the bar (e.g., on workspace change)
     * Shows for hideDelay duration before auto-hiding
     */
    function showTemporarily() {
        behavior.showTemporarily()
    }
    
    // Behavior controller
    BarBehavior {
        id: behavior
        mode: root.mode
        barHovered: root._realHover
        edgeHit: root.edgeHit
        hasActiveWindows: root.hasActiveWindows
    }
    
    // Computed visibility from behavior
    readonly property bool showBar: behavior.barVisible
    
    // Reusable transformation controller for slide and size animations
    BarTransform {
        id: barTransform
        target: root
        showBar: root.showBar
        expanded: false
        discreteMode: root.compactMode
        contentWidth: layout.implicitWidth
        contentHeight: 44
        
        // Compact mode dimensions (just workspaces widget)
        discreteWidth: workspacesWidget.implicitWidth + 16
        discreteHeight: 24
        normalHeight: 44
        collapsedPadding: 24
    }
    
    // Y position for glass backdrop sync - use binding to always match transform
    property real yPosition: barTransform.slideY
    
    // Slide animation using BarTransform
    transform: barTransform.slideTransform
    
    // Opacity follows showBar with matching duration
    opacity: showBar ? 1.0 : 0.0
    
    Behavior on opacity {
        NumberAnimation {
            duration: 400  // Match BarTransform.slideDuration
            easing.type: showBar ? Easing.OutBack : Easing.InQuad
        }
    }
    
    // Adaptive colors based on background
    AdaptiveColors {
        id: adaptiveColors
        region: "left"
    }

    ShadowBorder {
        radius: barTransform.animatedRadius
    }
    
    // Whether we're in compact mode (minimal UI - just workspaces)
    readonly property bool compactMode: behavior.isCompact

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        // Start icon (app launcher) - hidden in compact mode
        Rectangle {
            width: 34
            height: 34
            radius: Theme.barRoundness / 2
            color: startMouse.containsMouse ? Theme.current.hover : "transparent"
            visible: !root.compactMode
            opacity: root.compactMode ? 0 : 1
            
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Image {
                anchors.centerIn: parent
                source: "image://icon/nix-snowflake"
                sourceSize: Qt.size(22, 22)
                width: 22
                height: 22
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                text: "❄"
                font.pixelSize: 18
                color: adaptiveColors.iconColor
                visible: parent.children[0].status !== Image.Ready
            }

            MouseArea {
                id: startMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launcherRequested()
            }
        }

        // Overview button - hidden in compact mode
        Rectangle {
            width: 34
            height: 34
            radius: 10
            color: overviewMouse.containsMouse ? Theme.current.hover : "transparent"
            visible: !root.compactMode
            opacity: root.compactMode ? 0 : 1
            
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Text {
                anchors.centerIn: parent
                text: "▦"
                font.pixelSize: 16
                color: adaptiveColors.iconColor
            }

            MouseArea {
                id: overviewMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.overviewRequested()
            }
        }

        // Workspaces Widget - always visible
        WorkspacesWidget {
            id: workspacesWidget
            textColor: adaptiveColors.iconColor
        }
    }
    
    // Hover detection for the entire bar
    BarHoverDetector {
        onHoverChanged: (hovering) => {
            root._realHover = hovering
            root.barHoverChanged(hovering)
        }
    }
}
