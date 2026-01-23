import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../globals"
import "../../services"
import "../effects"
import "../behavior"
import "../transforms"

Item {
    id: root
    implicitWidth: barTransform.animatedWidth
    implicitHeight: barTransform.animatedHeight
    
    // Explicit size for BarHoverDetector
    width: barTransform.animatedWidth
    height: barTransform.animatedHeight

    signal powerRequested()
    signal toolbarRequested()
    signal barHoverChanged(bool hovering)
    signal trayMenuActiveChanged(bool active)
    signal volumeScrollChanged()  // Signal for volume scroll changes (GNOME-like)
    
    // Reference to the parent window for tray menus
    property var parentWindow: null

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
    
    /** Whether this bar is active (for disabling AdaptiveColors in fullscreen) */
    property bool active: true

    // Internal hover tracking
    property bool _realHover: false
    property bool _trayMenuActive: false
    
    /**
     * Temporarily show the bar (e.g., on activity/events)
     * Shows for hideDelay duration before auto-hiding
     */
    function showTemporarily() {
        behavior.showTemporarily()
    }
    
    // Behavior controller
    BarBehavior {
        id: behavior
        debugName: "StatusBar"
        mode: root.mode
        barHovered: root._realHover
        popupActive: root._trayMenuActive
        hasActiveWindows: root.hasActiveWindows
    }
    
    // Computed visibility from behavior
    readonly property bool showBar: behavior.barVisible
    
    // Volume control - use Audio service
    property real currentVolume: Audio.volume
    property bool volumeMuted: Audio.muted
    
    // Reusable transformation controller for slide and size animations
    BarTransform {
        id: barTransform
        target: root
        showBar: root.showBar
        expanded: false
        discreteMode: root.compactMode
        contentWidth: mainRow.implicitWidth
        contentHeight: 44
        
        // Compact mode dimensions (tray icons + volume indicator)
        discreteWidth: trayLayout.implicitWidth + 24 + (compactVolumeIndicator.visible ? compactVolumeIndicator.width + 8 : 0)
        discreteHeight: 24
        normalHeight: 44
        collapsedPadding: 0
    }
    
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
    
    // ═══════════════════════════════════════════════════════════════
    // EMBEDDED GLASS BACKDROP - Auto-syncs with bar dimensions
    // ═══════════════════════════════════════════════════════════════
    EmbeddedGlassBackdrop {
        backdropName: "right"
        horizontalAlign: "right"
        margin: 2
        targetRadius: barTransform.animatedRadius
        yOffset: barTransform.slideY
        backdropVisible: root.active
        startupDelay: 100
    }
    
    // Adaptive colors based on background
    AdaptiveColors {
        id: adaptiveColors
        region: "right"
        active: root.active
    }

    ShadowBorder {
        radius: barTransform.animatedRadius
    }
    
    // Whether we're in compact mode (minimal UI - just status indicators)
    readonly property bool compactMode: behavior.isCompact

    property string activeTrayItem: "" // Track which tray icon is right-clicked
    
    // Function to clear tray menu state (called from parent when clicking outside)
    function clearTrayMenu() {
        activeTrayItem = ""
    }
    
    // Menu anchor for system tray context menus - tracks menu open/close state
    QsMenuAnchor {
        id: trayMenuAnchor
        
        anchor.window: root.parentWindow
        // Position menu above the bar (anchor at top edge, menu grows upward)
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        
        onClosed: {
            // Menu closed - re-enable auto-hide
            root.activeTrayItem = ""
            root._trayMenuActive = false
            root.trayMenuActiveChanged(false)
        }
    }

    Row {
        id: mainRow
        anchors.centerIn: parent
        spacing: 8

        // System tray - ALWAYS visible (in compact mode, this is the ONLY thing shown)
        Item {
            width: trayLayout.implicitWidth + 20
            height: root.compactMode ? 24 : 44

            RowLayout {
                id: trayLayout
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: SystemTray.items
                    delegate: MouseArea {
                        id: trayItem
                        required property SystemTrayItem modelData
                        property int trayItemSize: 20
                        property string trayId: trayItem.modelData.id

                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        Layout.preferredWidth: trayItemSize
                        Layout.preferredHeight: trayItemSize
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: function(mouse) {
                             if (mouse.button === Qt.LeftButton) {
                                modelData.activate()
                            } else if (mouse.button === Qt.RightButton) {
                                if (modelData.hasMenu && root.parentWindow) {
                                    root.activeTrayItem = trayId
                                    root._trayMenuActive = true
                                    root.trayMenuActiveChanged(true)
                                    // Use QsMenuAnchor to open the menu - this tracks when it closes
                                    trayMenuAnchor.menu = modelData.menu
                                    // Set the anchor position relative to the parent window
                                    var iconPos = trayItem.mapToItem(null, trayItem.width / 2, 0)
                                    trayMenuAnchor.anchor.rect = Qt.rect(iconPos.x, iconPos.y, 1, 1)
                                    trayMenuAnchor.open()
                                }
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 4
                            height: parent.height + 4
                            radius: 4
                            color: adaptiveColors.textColor
                            visible: root.activeTrayItem === trayId
                            opacity:  0.1  
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }

                        // Tray icon with fallback
                        IconImage {
                            id: trayIcon
                            source: trayItem.modelData.icon
                            anchors.centerIn: parent
                            implicitWidth: trayItem.trayItemSize
                            implicitHeight: trayItem.trayItemSize
                            visible: status === Image.Ready
                        }
                        
                        // Fallback icon when tray icon fails to load
                        Text {
                            anchors.centerIn: parent
                            text: "●"
                            font.pixelSize: 14
                            color: adaptiveColors.iconColor
                            visible: trayIcon.status !== Image.Ready
                        }
                    }
                }
                 
            }
        }

        // Volume indicator for compact mode - scrollable like GNOME (positioned after tray)
        Item {
            id: compactVolumeIndicator
            width: 22
            height: root.compactMode ? 24 : 44
            visible: root.compactMode
            
            Text {
                anchors.centerIn: parent
                text: {
                    if (root.volumeMuted || root.currentVolume === 0) return "🔇"
                    if (root.currentVolume < 0.33) return "🔉"
                    return "🔊"
                }
                font.pixelSize: 14
                color: adaptiveColors.iconColor
            }
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                
                onClicked: Audio.toggleMute()
                
                onWheel: function(wheel) {
                    if (wheel.angleDelta.y > 0) {
                        Audio.incrementVolume()
                    } else {
                        Audio.decrementVolume()
                    }
                    root.volumeScrollChanged()
                }
            }
        }

        // Quick status island with GNOME-like scroll volume control - hidden in compact mode
        Item {
            width: statusLayout.implicitWidth + 20
            height: 44
            visible: !root.compactMode
            opacity: root.compactMode ? 0 : 1
            
            Behavior on opacity { NumberAnimation { duration: 200 } }

            RowLayout {
                id: statusLayout
                anchors.centerIn: parent
                spacing: 6

                // Volume indicator - scrollable like GNOME
                Item {
                    id: volumeIndicator
                    width: 28
                    height: 28
                    
                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (root.volumeMuted || root.currentVolume === 0) return "🔇"
                            if (root.currentVolume < 0.33) return "🔉"
                            if (root.currentVolume < 0.66) return "🔊"
                            return "🔊"
                        }
                        font.pixelSize: 15
                        color: adaptiveColors.iconColor
                    }
                    
                    // Mouse area for scroll wheel volume control
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        
                        // Click to toggle mute
                        onClicked: Audio.toggleMute()
                        
                        // Scroll wheel to adjust volume (GNOME-like)
                        onWheel: function(wheel) {
                            if (wheel.angleDelta.y > 0) {
                                Audio.incrementVolume()
                            } else {
                                Audio.decrementVolume()
                            }
                            
                            // Emit signal to trigger MainBar volume overlay
                            root.volumeScrollChanged()
                        }
                    }
                }

                // Network indicator  
                Item {
                    width: 28
                    height: 28
                    
                    Text {
                        anchors.centerIn: parent
                        text: Network.wifiEnabled ? (Network.wifiConnected ? "📶" : "📡") : "📵"
                        font.pixelSize: 15
                        color: adaptiveColors.iconColor
                    }
                }

                // Bluetooth
                Item {
                    width: 28
                    height: 28
                    visible: Bluetooth.enabled
                    
                    Text {
                        anchors.centerIn: parent
                        text: Bluetooth.connected ? "🔷" : "📳"
                        font.pixelSize: 13
                        color: adaptiveColors.iconColor
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toolbarRequested()
            }
        }

        // Theme toggle island
        // (Theme toggle removed)

        // Power island - hidden in compact mode
        Item {
            width: 44
            height: 44
            visible: !root.compactMode
            opacity: root.compactMode ? 0 : 1
            
            Behavior on opacity { NumberAnimation { duration: 200 } }


            Text {
                anchors.centerIn: parent
                text: "⏻"
                font.pixelSize: 16
                color: powerMouse.containsMouse ? "#ff6b6b" : adaptiveColors.iconColor
            }

            MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.powerRequested()
            }
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
