import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../globals"
import "../../services"
import "../effects"
import "../containers"

/**
 * AppPopup - App launcher:
 *   Top row: Search bar + tab toggles (inside BubbleContainer)
 *   Main area: Always-visible app grid (outside BubbleContainer)
 */
Item {
    id: root

    property bool show: false
    property int animDuration: State.animDuration ?? 300

    signal closeRequested()

    implicitWidth: 620
    implicitHeight: 460
    width: implicitWidth
    height: implicitHeight

    readonly property real originX: implicitWidth / 2
    readonly property real originY: implicitHeight

    property int screenX: 0
    property int screenY: 0

    // ── State ─────────────────────────────────────────────────────
    property string searchQuery: ""
    property int selectedIndex: -1
    property var displayedApps: []
    property var favoriteIds: []
    property var folders: ({})
    property string currentFolderId: ""

    // Storage
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/molten"
    readonly property string configPath: configDir + "/launcher.json"
    property string configContent: ""

    Process {
        id: readConfigProcess
        command: ["cat", root.configPath]
        stdout: SplitParser {
            onRead: data => {
                root.configContent = data
                root.loadConfig()
                root.updateContent()
            }
        }
    }

    Connections {
        target: AppSearch
        function onAppsReady() { readConfigProcess.running = true }
    }

    Component.onCompleted: {
        updateContent()
        readConfigProcess.running = true
    }

    onShowChanged: {
        if (show) {
            updateContent()
            readConfigProcess.running = true
            // Auto-focus search
            bubbleContainer.focusedItemId = "search"
        } else {
            searchQuery = ""
        }
    }

    function loadConfig() {
        try {
            if (configContent && configContent.length > 0) {
                var data = JSON.parse(configContent)
                favoriteIds = data.favoriteIds || []
                folders = data.folders || {}
            }
        } catch (e) { favoriteIds = []; folders = {} }
    }

    function saveConfig() {
        var data = { favoriteIds: favoriteIds, folders: folders }
        saveProcess.command = ["sh", "-c", "mkdir -p '" + configDir + "' && echo '" + JSON.stringify(data).replace(/'/g, "'\\''") + "' > '" + configPath + "'"]
        saveProcess.running = true
    }
    Process { id: saveProcess }

    function addToFavorites(appId) {
        if (favoriteIds.indexOf(appId) === -1) {
            var nf = favoriteIds.slice(); nf.push(appId); favoriteIds = nf
            saveConfig(); updateContent()
        }
    }
    function removeFromFavorites(appId) {
        var idx = favoriteIds.indexOf(appId)
        if (idx !== -1) {
            var nf = favoriteIds.slice(); nf.splice(idx, 1); favoriteIds = nf
            saveConfig(); updateContent()
        }
    }
    function isFavorite(appId) { return favoriteIds.indexOf(appId) !== -1 }
    function getAppById(appId) {
        var all = AppSearch.getAllApps()
        for (var i = 0; i < all.length; i++) if (all[i].id === appId) return all[i]
        return null
    }

    onSearchQueryChanged: updateContent()

    function updateContent() {
        if (searchQuery.length > 0) {
            var results = AppSearch.fuzzyQuery(searchQuery); var items = []
            for (var i = 0; i < results.length; i++) items.push(Object.assign({}, results[i], { type: "app" }))
            displayedApps = items
        } else {
            var apps = AppSearch.getAllApps(); var items2 = []
            for (var i = 0; i < apps.length; i++) items2.push(Object.assign({}, apps[i], { type: "app" }))
            displayedApps = items2
        }
        selectedIndex = -1
    }

    function executeApp(app) {
        if (app && app.execute) { app.execute(); root.closeRequested() }
    }

    // ── Top row container (bubbles for search + tabs) ─────────────
    BubbleContainer {
        id: bubbleContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 100
        show: root.show
        animDuration: root.animDuration
        originX: root.originX
        originY: root.implicitHeight  // animate from bottom of popup
        screenX: root.screenX
        screenY: root.screenY
    }

    readonly property bool isDark: bubbleContainer.isDark
    readonly property color textColor: bubbleContainer.textColor
    readonly property color subtleColor: bubbleContainer.subtleColor
    readonly property color iconColor: bubbleContainer.iconColor

    // ═════════════════════════════════════════════════════════════════
    // TOP ROW — Search bubble only
    // ═════════════════════════════════════════════════════════════════

    // ── Search bar (auto-focused on open) ─────────────────────────
    Bubble {
        id: searchBubble
        parent: bubbleContainer
        itemId: "search"
        itemX: root.implicitWidth / 2;  itemY: 50
        itemWidth: 340;  itemHeight: 48
        animIndex: 0

        SearchContent {
            anchors.fill: parent
            focused: searchBubble.isFocused
        }
    }

    // ═════════════════════════════════════════════════════════════════
    // APP GRID — Always visible, outside the BubbleContainer
    // ═════════════════════════════════════════════════════════════════

    Item {
        id: appGridArea
        anchors.top: bubbleContainer.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12

        // Slide-in animation
        property real animProgress: root.show ? 1 : 0
        Behavior on animProgress {
            NumberAnimation {
                duration: root.animDuration + 80
                easing.type: Easing.OutBack; easing.overshoot: 1.2
            }
        }

        opacity: animProgress
        Behavior on opacity { NumberAnimation { duration: 200 } }

        transform: [
            Translate {
                y: (1 - appGridArea.animProgress) * 60
            },
            Scale {
                origin.x: appGridArea.width / 2
                origin.y: 0
                xScale: 0.85 + appGridArea.animProgress * 0.15
                yScale: 0.85 + appGridArea.animProgress * 0.15
            }
        ]

        BlurContainer {
            anchors.fill: parent
            radius: 18
            hovered: false
            backgroundIsDark: root.isDark
            externalTextColor: root.textColor
            externalSubtleColor: root.subtleColor
            externalIconColor: root.iconColor
        }

        // Header
        RowLayout {
            id: gridHeader
            anchors.top: parent.top; anchors.topMargin: 12
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.right: parent.right; anchors.rightMargin: 16
            spacing: 8
            z: 1

            Text {
                text: root.searchQuery.length > 0 ? Icons.glassPlus : Icons.dotsNine
                font.family: Icons.font; font.pixelSize: 14
                color: root.iconColor
            }
            Text {
                Layout.fillWidth: true
                text: root.searchQuery.length > 0
                      ? (root.displayedApps.length + " result" + (root.displayedApps.length !== 1 ? "s" : ""))
                      : (root.displayedApps.length + " app" + (root.displayedApps.length !== 1 ? "s" : ""))
                color: root.subtleColor
                font.pixelSize: 11
            }
        }

        // Grid
        Flickable {
            anchors.top: gridHeader.bottom; anchors.topMargin: 8
            anchors.left: parent.left; anchors.leftMargin: 8
            anchors.right: parent.right; anchors.rightMargin: 8
            anchors.bottom: parent.bottom; anchors.bottomMargin: 8
            clip: true
            contentHeight: appGrid.height
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            GridLayout {
                id: appGrid
                width: parent.width
                columns: 5
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    model: root.displayedApps

                    Item {
                        Layout.preferredWidth: (appGrid.width - appGrid.columnSpacing * (appGrid.columns - 1)) / appGrid.columns
                        Layout.preferredHeight: Layout.preferredWidth + 14

                        Rectangle {
                            anchors.fill: parent; radius: 10
                            color: appMouse.containsMouse
                                   ? (root.isDark ? Qt.rgba(1,1,1,0.1) : Qt.rgba(0,0,0,0.05))
                                   : "transparent"
                        }

                        Column {
                            anchors.centerIn: parent; spacing: 4

                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 38; height: 38
                                source: "image://icon/" + modelData.icon
                                sourceSize.width: 40; sourceSize.height: 40
                                fillMode: Image.PreserveAspectFit; smooth: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.name
                                color: root.textColor
                                font.pixelSize: 10
                                width: (appGrid.width - appGrid.columnSpacing * (appGrid.columns - 1)) / appGrid.columns - 8
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: appMouse
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    if (root.isFavorite(modelData.id)) root.removeFromFavorites(modelData.id)
                                    else root.addToFavorites(modelData.id)
                                } else {
                                    root.executeApp(modelData)
                                }
                            }
                        }
                    }
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent; spacing: 8
                visible: root.displayedApps.length === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Icons.apps
                    font.family: Icons.font
                    font.pixelSize: 32
                    color: root.subtleColor; opacity: 0.4
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.searchQuery.length > 0 ? "No results found" : "No apps found"
                    color: root.subtleColor; font.pixelSize: 12
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════
    // CONTENT COMPONENTS
    // ═════════════════════════════════════════════════════════════════

    // ── Search content (inline search bar, always shows input) ───
    component SearchContent: Item {
        id: searchContent
        property bool focused: false

        BlurContainer {
            anchors.fill: parent
            radius: height / 2
            hovered: searchContent.focused
            backgroundIsDark: root.isDark
            externalTextColor: root.textColor
            externalSubtleColor: root.subtleColor
            externalIconColor: root.iconColor
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16; anchors.rightMargin: 16
            spacing: 8

            Text {
                text: Icons.glassPlus
                font.family: Icons.font
                font.pixelSize: 16
                color: root.iconColor
            }

            TextInput {
                id: searchInput
                Layout.fillWidth: true
                color: root.textColor
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                text: root.searchQuery

                Text {
                    anchors.fill: parent
                    text: "Search apps…"
                    color: root.subtleColor
                    font.pixelSize: 13
                    visible: !searchInput.text && !searchInput.activeFocus
                    verticalAlignment: Text.AlignVCenter
                }

                onTextChanged: root.searchQuery = text
            }

            Text {
                text: Icons.cancel
                font.family: Icons.font
                font.pixelSize: 12
                color: root.subtleColor
                visible: searchInput.text.length > 0
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { searchInput.text = ""; searchInput.forceActiveFocus() }
                }
            }
        }

        // Auto-focus input when popup opens
        Connections {
            target: root
            function onShowChanged() {
                if (root.show) {
                    searchInput.text = ""
                    Qt.callLater(() => searchInput.forceActiveFocus())
                }
            }
        }

        MouseArea {
            anchors.fill: parent; hoverEnabled: true
            propagateComposedEvents: true
            cursorShape: Qt.IBeamCursor
            onClicked: searchInput.forceActiveFocus()
            onPressed: (mouse) => mouse.accepted = false
        }
    }

    // ═════════════════════════════════════════════════════════════════
    // BUBBLE & TRANSFORM BUBBLE
    // ═════════════════════════════════════════════════════════════════

    component Bubble: Item {
        id: bubble
        default property alias content: visual.data

        property string itemId: ""
        property real itemX: 0
        property real itemY: 0
        property real itemWidth: 70
        property real itemHeight: 70
        property int animIndex: 0

        readonly property bool isFocused: bubbleContainer.focusedItemId === itemId
        readonly property bool isUnfocused: bubbleContainer.focusedItemId !== "" && !isFocused

        width: itemWidth;  height: itemHeight
        x: itemX - itemWidth / 2
        y: itemY - itemHeight / 2

        Component.onCompleted: bubbleContainer.registerItem(itemId, itemX, itemY, itemWidth, itemHeight)
        Component.onDestruction: bubbleContainer.unregisterItem(itemId)

        readonly property real targetScale: isFocused ? 1.15 : (isUnfocused ? 0.75 : 1.0)
        property real hoverScale: 1.0
        Behavior on hoverScale {
            NumberAnimation {
                duration: bubble.isFocused ? 150 : 350
                easing.type: bubble.isFocused ? Easing.OutBack : Easing.InOutCubic
                easing.overshoot: bubble.isFocused ? 1.2 : 1.0
            }
        }
        onTargetScaleChanged: hoverScale = targetScale

        z: isFocused ? 100 : (isUnfocused ? 1 : 10)

        property real floatY: 0
        SequentialAnimation on floatY {
            running: root.show && !bubble.isFocused
            loops: Animation.Infinite
            NumberAnimation { to: 3;  duration: 2000 + bubble.animIndex * 200; easing.type: Easing.InOutSine }
            NumberAnimation { to: -3; duration: 2000 + bubble.animIndex * 200; easing.type: Easing.InOutSine }
        }

        property real animProgress: root.show ? 1 : 0
        Behavior on animProgress {
            NumberAnimation {
                duration: root.animDuration + bubble.animIndex * 40
                easing.type: Easing.OutBack; easing.overshoot: 1.5
            }
        }

        Item {
            id: visual
            width: bubble.itemWidth;  height: bubble.itemHeight
            y: bubble.floatY
            transform: [
                Translate {
                    x: (root.originX - bubble.x - bubble.itemWidth / 2) * (1 - bubble.animProgress)
                    y: (root.originY - bubble.y - bubble.itemHeight / 2) * (1 - bubble.animProgress)
                },
                Scale {
                    origin.x: bubble.itemWidth / 2
                    origin.y: bubble.itemHeight
                    xScale: bubble.animProgress * bubble.hoverScale
                    yScale: bubble.animProgress * bubble.hoverScale
                }
            ]
            opacity: bubble.animProgress * (bubble.isUnfocused ? 0.25 : 1.0)
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

}
