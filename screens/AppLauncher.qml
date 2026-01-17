import QtQuick
import QtQuick.Layouts
import "../components"
import ".."

Item {
    id: root
    implicitWidth: 500
    implicitHeight: 550

    signal closeRequested()

    property string currentTab: "favorites"
    property string searchQuery: ""

    // Adaptive colors based on background
    AdaptiveColors {
        id: adaptiveColors
        region: "notch"
    }

    // Sample apps
    property var allApps: [
        { name: "Firefox", icon: "🦊", desktopFile: "firefox.desktop" },
        { name: "Files", icon: "📁", desktopFile: "org.gnome.Nautilus.desktop" },
        { name: "Terminal", icon: "💻", desktopFile: "org.gnome.Terminal.desktop" },
        { name: "Settings", icon: "⚙️", desktopFile: "gnome-control-center.desktop" },
        { name: "Code", icon: "📝", desktopFile: "code.desktop" },
        { name: "Spotify", icon: "🎵", desktopFile: "spotify.desktop" },
        { name: "Discord", icon: "💬", desktopFile: "discord.desktop" },
        { name: "Steam", icon: "🎮", desktopFile: "steam.desktop" },
        { name: "Chrome", icon: "🌐", desktopFile: "google-chrome.desktop" },
        { name: "GIMP", icon: "🎨", desktopFile: "gimp.desktop" },
        { name: "VLC", icon: "🎬", desktopFile: "vlc.desktop" },
        { name: "Calculator", icon: "🔢", desktopFile: "org.gnome.Calculator.desktop" }
    ]

    property var favorites: [
        { name: "Firefox", icon: "🦊", desktopFile: "firefox.desktop" },
        { name: "Terminal", icon: "💻", desktopFile: "org.gnome.Terminal.desktop" },
        { name: "Files", icon: "📁", desktopFile: "org.gnome.Nautilus.desktop" },
        { name: "Code", icon: "📝", desktopFile: "code.desktop" }
    ]

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Search bar
        Item {
            width: parent.width
            height: 44
           
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                z: 1

                Text {
                    text: "🔍"
                    color: adaptiveColors.textColor
                    font.pixelSize: 16
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    color: adaptiveColors.textColor
                    font.pixelSize: 14
                    clip: true
                    selectByMouse: true

                    Text {
                        anchors.fill: parent
                        text: "Search apps..."
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 14
                        visible: !searchInput.text && !searchInput.activeFocus
                    }

                    onTextChanged: root.searchQuery = text
                }

                Text {
                    text: "✕"
                    color: adaptiveColors.subtleTextColor
                    font.pixelSize: 14
                    visible: searchInput.text.length > 0

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchInput.text = ""
                    }
                }
            }
        }

        // Tabs
        RowLayout {
            width: parent.width
            spacing: 8

            Repeater {
                model: [
                    { id: "favorites", label: "Favorites" },
                    { id: "all", label: "All Apps" }
                ]

                Item {
                    Layout.fillWidth: true
                    height: 36
                   
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: root.currentTab === modelData.id ? adaptiveColors.textColor : adaptiveColors.subtleTextColor
                        font.pixelSize: 13
                        font.weight: root.currentTab === modelData.id ? Font.Medium : Font.Normal
                        z: 1
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = modelData.id
                    }
                }
            }
        }

        // App grid
        Flickable {
            width: parent.width
            height: parent.height - 120
            clip: true
            contentHeight: appGrid.height
            boundsBehavior: Flickable.StopAtBounds

            GridLayout {
                id: appGrid
                width: parent.width
                columns: 5
                rowSpacing: 12
                columnSpacing: 12

                Repeater {
                    model: {
                        var apps = root.currentTab === "favorites" ? root.favorites : root.allApps
                        
                        if (root.searchQuery) {
                            apps = root.allApps.filter(function(app) {
                                return app.name.toLowerCase().indexOf(root.searchQuery.toLowerCase()) !== -1
                            })
                        }
                        
                        // Sort alphabetically for all apps
                        if (root.currentTab === "all" || root.searchQuery) {
                            apps = apps.slice().sort(function(a, b) { return a.name.localeCompare(b.name) })
                        }
                        
                        return apps
                    }

                    Item {
                        width: 80
                        height: 90
                        
                                         Column {
                            anchors.centerIn: parent
                            spacing: 6
                            z: 1

                            Item {
                                width: 48
                                height: 48
                                anchors.horizontalCenter: parent.horizontalCenter
                                
                                                            Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon || "📦"
                                    font.pixelSize: 24
                                    z: 1
                                }
                            }

                            Text {
                                text: modelData.name || "App"
                                color: adaptiveColors.textColor
                                font.pixelSize: 11
                                width: 70
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                State.launchApp(modelData.desktopFile)
                                root.closeRequested()
                            }
                        }
                    }
                }
            }
        }
    }
}
