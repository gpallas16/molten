import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../globals"
import "../effects"
import "../behavior"

Item {
    id: root
    implicitWidth: mainRow.implicitWidth
    implicitHeight: 44

    signal powerRequested()
    signal toolbarRequested()
    signal barHoverChanged(bool hovering)
    signal trayMenuActiveChanged(bool active)
    
    // Reference to the parent window for tray menus
    property var parentWindow: null

    // Auto-hide state (controlled by parent)
    property bool showBar: false
    
    // Y position for glass backdrop sync - use binding to always match transform
    property real yPosition: slideTransform.y
    
    // Slide animation: translate Y when hiding
    transform: Translate {
        id: slideTransform
        y: showBar ? 0 : (root.height + 20)
        
        Behavior on y {
            NumberAnimation {
                duration: 400
                easing.type: showBar ? Easing.OutBack : Easing.InQuad
                easing.overshoot: 1.2
            }
        }
    }
    
    opacity: showBar ? 1.0 : 0.0
    
    Behavior on opacity {
        NumberAnimation {
            duration: showBar ? 300 : 200
            easing.type: Easing.InOutQuad
        }
    }
    
    // Adaptive colors based on background
    AdaptiveColors {
        id: adaptiveColors
        region: "right"
    }
    
    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    ShadowBorder {
        radius: Theme.barRoundness
    }

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
            root.trayMenuActiveChanged(false)
        }
    }

    Row {
        id: mainRow
        anchors.centerIn: parent
        spacing: 8

        Item {
            width: trayLayout.implicitWidth + 20
            height: 44
            // visible: SystemTray.items.length > 0

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

                        IconImage {
                            id: trayIcon
                            source: trayItem.modelData.icon
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            smooth: true
                        }
                    }
                }
                 
            }
        }

        // Quick status island
        Item {
            width: statusLayout.implicitWidth + 20
            height: 44

            RowLayout {
                id: statusLayout
                anchors.centerIn: parent
                spacing: 6

                // Volume indicator
                Item {
                    width: 28
                    height: 28
                    
                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (State.volume === 0) return "🔇"
                            if (State.volume < 0.5) return "🔉"
                            return "🔊"
                        }
                        font.pixelSize: 15
                        color: adaptiveColors.iconColor
                    }
                }

                // Network indicator  
                Item {
                    width: 28
                    height: 28
                    
                    Text {
                        anchors.centerIn: parent
                        text: State.wifiEnabled ? "📶" : "📵"
                        font.pixelSize: 15
                        color: adaptiveColors.iconColor
                    }
                }

                // Bluetooth
                Item {
                    width: 28
                    height: 28
                    visible: State.bluetoothEnabled !== undefined ? State.bluetoothEnabled : false
                    
                    Text {
                        anchors.centerIn: parent
                        text: "🔷"
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

        // Power island
        Item {
            width: 44
            height: 44


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
        onHoverChanged: (hovering) => root.barHoverChanged(hovering)
    }
}
