import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../globals"
import "../services"
import "../components/effects"

Item {
    id: root
    implicitWidth: 400
    implicitHeight: 500

    signal closeRequested()

    // Forward focus to search input
    onActiveFocusChanged: if (activeFocus) searchInput.forceActiveFocus()

    // Search/filter state
    property string searchQuery: ""
    property int selectedIndex: 0

    // Filtered history
    property var filteredHistory: {
        if (searchQuery === "") return Clipboard.history
        var query = searchQuery.toLowerCase()
        return Clipboard.history.filter(function(item) {
            return item.preview.toLowerCase().includes(query)
        })
    }

    // Adaptive colors
    AdaptiveColors {
        id: adaptiveColors
        region: "notch"
    }

    // Keyboard navigation
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            selectedIndex = Math.min(selectedIndex + 1, filteredHistory.length - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            selectedIndex = Math.max(selectedIndex - 1, 0)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (filteredHistory.length > 0 && selectedIndex >= 0) {
                pasteItem(filteredHistory[selectedIndex])
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Delete) {
            if (filteredHistory.length > 0 && selectedIndex >= 0) {
                Clipboard.remove(filteredHistory[selectedIndex].id)
            }
            event.accepted = true
        }
    }

    function pasteItem(item) {
        Clipboard.paste(item.id)
        root.closeRequested()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            width: parent.width
            spacing: 12

            Text {
                text: "📋"
                font.pixelSize: 20
            }

            Text {
                text: "Clipboard History"
                color: adaptiveColors.textColor
                font.pixelSize: 16
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            // Clear all button
            Rectangle {
                width: 28
                height: 28
                radius: 6
                color: clearMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.2) : "transparent"
                
                Text {
                    anchors.centerIn: parent
                    text: "🗑️"
                    font.pixelSize: 14
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Clipboard.clear()
                }
            }
        }

        // Search input
        Rectangle {
            width: parent.width
            height: 40
            radius: 10
            color: adaptiveColors.textColor
            opacity: 0.08

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "🔍"
                    font.pixelSize: 14
                    opacity: 0.6
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: adaptiveColors.textColor
                    font.pixelSize: 14
                    clip: true
                    selectByMouse: true

                    onTextChanged: {
                        root.searchQuery = text
                        root.selectedIndex = 0
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !searchInput.text
                        text: "Search clipboard..."
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 14
                    }
                }

                // Clear search
                Text {
                    visible: searchInput.text !== ""
                    text: "✕"
                    font.pixelSize: 12
                    color: adaptiveColors.subtleTextColor
                    
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchInput.text = ""
                    }
                }
            }
        }

        // Error message
        Rectangle {
            visible: Clipboard.error !== ""
            width: parent.width
            height: 40
            radius: 8
            color: Qt.rgba(1, 0.3, 0.3, 0.2)

            Text {
                anchors.centerIn: parent
                text: Clipboard.error
                color: "#ff6666"
                font.pixelSize: 12
            }
        }

        // Clipboard list
        ListView {
            id: clipboardList
            width: parent.width
            height: parent.height - 120
            clip: true
            spacing: 4
            model: filteredHistory
            currentIndex: selectedIndex

            delegate: Rectangle {
                id: clipItem
                width: clipboardList.width
                height: 60
                radius: 8
                color: {
                    if (index === root.selectedIndex) return Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.15)
                    if (itemMouse.containsMouse) return Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.08)
                    return "transparent"
                }

                property var itemData: modelData

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    // Icon
                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 6
                        color: adaptiveColors.textColor
                        opacity: 0.1

                        Text {
                            anchors.centerIn: parent
                            text: itemData.isImage ? "🖼️" : "📄"
                            font.pixelSize: 18
                        }
                    }

                    // Preview text
                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            width: parent.width
                            text: itemData.isImage ? "[Image]" : itemData.preview.substring(0, 100)
                            color: adaptiveColors.textColor
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WrapAnywhere
                        }

                        Text {
                            text: itemData.isImage ? "Binary data" : (itemData.preview.length + " chars")
                            color: adaptiveColors.subtleTextColor
                            font.pixelSize: 10
                        }
                    }

                    // Delete button
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 6
                        color: deleteMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.2) : "transparent"
                        visible: itemMouse.containsMouse || index === root.selectedIndex

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 12
                            color: adaptiveColors.subtleTextColor
                        }

                        MouseArea {
                            id: deleteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Clipboard.remove(itemData.id)
                        }
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: -1
                    
                    onClicked: root.pasteItem(itemData)
                    onEntered: root.selectedIndex = index
                }
            }

            // Empty state
            Item {
                visible: filteredHistory.length === 0
                anchors.centerIn: parent
                width: parent.width
                height: 100

                Column {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "📋"
                        font.pixelSize: 32
                        opacity: 0.5
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: searchQuery !== "" ? "No matches found" : "Clipboard is empty"
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 14
                    }
                }
            }
        }

        // Hint text
        Text {
            width: parent.width
            text: "↵ Paste  •  Del Remove  •  Esc Close"
            color: adaptiveColors.subtleTextColor
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
