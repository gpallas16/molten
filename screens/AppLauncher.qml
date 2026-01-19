import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../components"
import "../globals"
import "../services"

Item {
    id: root
    implicitWidth: 520
    implicitHeight: 600

    signal closeRequested()

    // State
    property string currentTab: "favorites"
    property string searchQuery: ""
    property int selectedIndex: -1
    property bool keyboardMode: false
    property string currentFolderId: ""
    property bool autoSwitchedFromFavorites: false

    // Drag and drop state
    property var draggedItem: null
    property int draggedIndex: -1
    property var dropTargetItem: null
    property int dropTargetIndex: -1
    property bool isDragging: false
    property point dragStartPos: Qt.point(0, 0)

    // Helper function to find item at position during drag
    function findItemAtPosition(mouseX, mouseY) {
        if (!favoritesRepeater || displayedApps.length === 0) return -1
        
        // Get the grid's position relative to root
        var gridGlobalPos = favoritesGrid.mapToItem(root, 0, 0)
        
        // Adjust for scroll position
        var scrollY = favoritesFlickable.contentY
        
        for (var i = 0; i < favoritesRepeater.count; i++) {
            var item = favoritesRepeater.itemAt(i)
            if (item && i !== root.draggedIndex) {
                // Map item position to root coordinates
                var itemPos = item.mapToItem(root, 0, 0)
                
                // Check if mouse is within item bounds
                if (mouseX >= itemPos.x && mouseX <= itemPos.x + item.width &&
                    mouseY >= itemPos.y && mouseY <= itemPos.y + item.height) {
                    return i
                }
            }
        }
        return -1
    }

    // Context menu state
    property var contextMenuItem: null
    property point contextMenuPos: Qt.point(0, 0)
    property bool showContextMenu: false

    // Helper function for context menu items (avoids scope issues in Repeater)
    function getContextMenuItems() {
        var items = []
        if (!contextMenuItem) return items

        if (contextMenuItem.type === "folder") {
            items.push({ action: "openFolder", label: "Open Folder", icon: "📂" })
            items.push({ action: "renameFolder", label: "Rename Folder", icon: "✏️" })
            items.push({ action: "deleteFolder", label: "Delete Folder", icon: "🗑️" })
        } else {
            items.push({ action: "launch", label: "Launch", icon: "▶️" })
            
            if (isFavorite(contextMenuItem.id)) {
                items.push({ action: "removeFavorite", label: "Remove from Favorites", icon: "☆" })
            } else {
                items.push({ action: "addFavorite", label: "Add to Favorites", icon: "★" })
            }

            // If in a folder, show remove from folder option
            if (currentFolderId !== "") {
                items.push({ action: "removeFromFolder", label: "Remove from Folder", icon: "📤" })
            }
        }
        return items
    }

    // Data (loaded from storage)
    property var favoriteIds: []      // Ordered list of favorite app IDs
    property var folders: ({})        // { folderId: { name: string, apps: string[] } }

    // Displayed items
    property var displayedApps: []

    // Storage path
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/molten"
    readonly property string configPath: configDir + "/launcher.json"

    AdaptiveColors {
        id: adaptiveColors
        region: "notch"
    }

    // File IO for persistence - use Process for reliable reading
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
    
    // Ensure config loads after component is ready
    Timer {
        id: loadTimer
        interval: 50
        running: true
        onTriggered: {
            readConfigProcess.running = true
        }
    }

    Connections {
        target: AppSearch
        function onAppsReady() {
            // Reload config when apps are ready to ensure favorites show
            readConfigProcess.running = true
        }
    }

    Component.onCompleted: {
        updateContent()
        searchInput.forceActiveFocus()
    }

    // ============ PERSISTENCE ============

    function loadConfig() {
        try {
            if (configContent && configContent.length > 0) {
                var data = JSON.parse(configContent)
                favoriteIds = data.favoriteIds || []
                folders = data.folders || {}
            }
        } catch (e) {
            console.log("AppLauncher: Could not load config:", e)
            favoriteIds = []
            folders = {}
        }
    }

    function saveConfig() {
        var data = {
            favoriteIds: favoriteIds,
            folders: folders
        }
        
        // Create directory if needed and write file
        saveProcess.command = ["sh", "-c", "mkdir -p '" + configDir + "' && echo '" + JSON.stringify(data).replace(/'/g, "'\\''") + "' > '" + configPath + "'"]
        saveProcess.running = true
    }

    Process {
        id: saveProcess
    }

    // ============ FAVORITES MANAGEMENT ============

    function addToFavorites(appId) {
        if (favoriteIds.indexOf(appId) === -1) {
            var newFavs = favoriteIds.slice()
            newFavs.push(appId)
            favoriteIds = newFavs
            saveConfig()
            updateContent()
        }
    }

    function removeFromFavorites(appId) {
        var idx = favoriteIds.indexOf(appId)
        if (idx !== -1) {
            var newFavs = favoriteIds.slice()
            newFavs.splice(idx, 1)
            favoriteIds = newFavs
            saveConfig()
            updateContent()
        }
        // Also remove from any folder
        removeAppFromAllFolders(appId)
    }

    function isFavorite(appId) {
        return favoriteIds.indexOf(appId) !== -1 || isAppInAnyFolder(appId)
    }

    function moveFavorite(fromIndex, toIndex) {
        if (fromIndex === toIndex) return
        var newFavs = favoriteIds.slice()
        var item = newFavs.splice(fromIndex, 1)[0]
        newFavs.splice(toIndex, 0, item)
        favoriteIds = newFavs
        saveConfig()
        updateContent()
    }

    // ============ FOLDER MANAGEMENT ============

    function createFolder(name, app1Id, app2Id) {
        var folderId = "folder_" + Date.now()
        var newFolders = Object.assign({}, folders)
        newFolders[folderId] = { name: name, apps: [app1Id, app2Id] }
        folders = newFolders

        // Remove apps from main favorites list
        var newFavs = favoriteIds.filter(function(id) {
            return id !== app1Id && id !== app2Id
        })
        favoriteIds = newFavs

        saveConfig()
        updateContent()
        return folderId
    }

    function renameFolder(folderId, newName) {
        if (!folders[folderId]) return
        var newFolders = Object.assign({}, folders)
        newFolders[folderId].name = newName
        folders = newFolders
        saveConfig()
        updateContent()
    }

    function deleteFolder(folderId) {
        if (!folders[folderId]) return
        var newFolders = Object.assign({}, folders)
        var appsInFolder = newFolders[folderId].apps || []
        delete newFolders[folderId]
        folders = newFolders

        // Move apps back to favorites
        var newFavs = favoriteIds.slice()
        for (var i = 0; i < appsInFolder.length; i++) {
            if (newFavs.indexOf(appsInFolder[i]) === -1) {
                newFavs.push(appsInFolder[i])
            }
        }
        favoriteIds = newFavs

        if (currentFolderId === folderId) currentFolderId = ""
        saveConfig()
        updateContent()
    }

    function addAppToFolder(appId, folderId) {
        if (!folders[folderId]) return
        var newFolders = Object.assign({}, folders)

        // Remove from other folders first
        for (var key in newFolders) {
            var idx = newFolders[key].apps.indexOf(appId)
            if (idx !== -1) newFolders[key].apps.splice(idx, 1)
        }

        // Add to target folder
        if (newFolders[folderId].apps.indexOf(appId) === -1) {
            newFolders[folderId].apps.push(appId)
        }
        folders = newFolders

        // Remove from main favorites
        var newFavs = favoriteIds.filter(function(id) { return id !== appId })
        favoriteIds = newFavs

        saveConfig()
        updateContent()
    }

    function removeAppFromFolder(appId, folderId) {
        if (!folders[folderId]) return
        var newFolders = Object.assign({}, folders)
        var idx = newFolders[folderId].apps.indexOf(appId)
        if (idx !== -1) {
            newFolders[folderId].apps.splice(idx, 1)
        }
        folders = newFolders

        // Add back to favorites
        if (favoriteIds.indexOf(appId) === -1) {
            var newFavs = favoriteIds.slice()
            newFavs.push(appId)
            favoriteIds = newFavs
        }

        saveConfig()
        updateContent()
    }

    function removeAppFromAllFolders(appId) {
        var newFolders = Object.assign({}, folders)
        var changed = false
        for (var key in newFolders) {
            var idx = newFolders[key].apps.indexOf(appId)
            if (idx !== -1) {
                newFolders[key].apps.splice(idx, 1)
                changed = true
            }
        }
        if (changed) {
            folders = newFolders
            saveConfig()
        }
    }

    function isAppInAnyFolder(appId) {
        for (var key in folders) {
            if (folders[key].apps.indexOf(appId) !== -1) return key
        }
        return null
    }

    function getAppById(appId) {
        var allApps = AppSearch.getAllApps()
        for (var i = 0; i < allApps.length; i++) {
            if (allApps[i].id === appId) return allApps[i]
        }
        return null
    }

    // ============ SEARCH HANDLING ============

    onSearchQueryChanged: {
        if (searchQuery.length > 0) {
            if (currentTab === "favorites") {
                autoSwitchedFromFavorites = true
            }
            currentTab = "all"
            searchInput.forceActiveFocus()
        } else {
            if (autoSwitchedFromFavorites) {
                currentTab = "favorites"
                autoSwitchedFromFavorites = false
            }
        }
        updateContent()
    }

    // ============ CONTENT UPDATE ============

    function updateContent() {
        if (searchQuery.length > 0) updateSearchResults()
        else if (currentTab === "favorites") updateFavorites()
        else updateAllApps()
    }

    function updateFavorites() {
        var allApps = AppSearch.getAllApps()
        var items = []

        if (currentFolderId === "") {
            // Show folders first
            for (var folderId in folders) {
                items.push({
                    type: "folder",
                    id: folderId,
                    name: folders[folderId].name,
                    icon: "folder",
                    appCount: folders[folderId].apps.length,
                    apps: folders[folderId].apps
                })
            }
            // Then show favorite apps (in order)
            for (var i = 0; i < favoriteIds.length; i++) {
                var app = getAppById(favoriteIds[i])
                if (app) {
                    items.push(Object.assign({}, app, { type: "app", favIndex: i }))
                }
            }
        } else {
            // Inside a folder - show apps in folder
            var folder = folders[currentFolderId]
            if (folder) {
                for (var j = 0; j < folder.apps.length; j++) {
                    var folderApp = getAppById(folder.apps[j])
                    if (folderApp) {
                        items.push(Object.assign({}, folderApp, { type: "app", folderIndex: j }))
                    }
                }
            }
        }

        displayedApps = items
        selectedIndex = -1
        keyboardMode = false
    }

    function updateAllApps() {
        var apps = AppSearch.getAllApps()
        var items = []
        for (var i = 0; i < apps.length; i++) {
            items.push(Object.assign({}, apps[i], { type: "app" }))
        }
        displayedApps = items
        selectedIndex = -1
        keyboardMode = false
    }

    function updateSearchResults() {
        var results = AppSearch.fuzzyQuery(searchQuery)
        var items = []
        for (var i = 0; i < results.length; i++) {
            items.push(Object.assign({}, results[i], { type: "app" }))
        }
        displayedApps = items
        selectedIndex = -1
        keyboardMode = false
    }

    function executeApp(app) {
        if (app && app.execute) {
            app.execute()
            root.closeRequested()
        }
    }

    // ============ KEYBOARD NAVIGATION ============

    Keys.onPressed: function(event) {
        if (showContextMenu) {
            if (event.key === Qt.Key_Escape) {
                showContextMenu = false
                event.accepted = true
            }
            return
        }

        keyboardMode = true
        if (event.key === Qt.Key_Escape) {
            if (searchQuery.length > 0) {
                searchInput.text = ""
                searchQuery = ""
            } else {
                root.closeRequested()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            if (selectedIndex < displayedApps.length - 1) {
                selectedIndex++
                if (currentTab !== "favorites" && allAppsList) {
                    allAppsList.positionViewAtIndex(selectedIndex, ListView.Contain)
                }
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            if (selectedIndex > 0) {
                selectedIndex--
                if (currentTab !== "favorites" && allAppsList) {
                    allAppsList.positionViewAtIndex(selectedIndex, ListView.Contain)
                }
            } else if (selectedIndex === 0) {
                selectedIndex = -1
                searchInput.forceActiveFocus()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (selectedIndex >= 0 && selectedIndex < displayedApps.length) {
                var item = displayedApps[selectedIndex]
                if (item.type === "folder") {
                    currentFolderId = item.id
                    updateContent()
                } else {
                    executeApp(item)
                }
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            if (searchQuery.length === 0) {
                currentTab = currentTab === "favorites" ? "all" : "favorites"
                updateContent()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
            if (searchQuery.length === 0 && currentFolderId !== "") {
                currentFolderId = ""
                updateContent()
                event.accepted = true
            }
        }
    }

    // ============ UI ============

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Search bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 12
            color: "#23272e"
            border.width: 2
            border.color: "#444a57"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

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
                        text: "Search applications..."
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 14
                        visible: !searchInput.text && !searchInput.activeFocus
                    }

                    onTextChanged: { root.searchQuery = text }
                    Keys.onDownPressed: { if (displayedApps.length > 0) selectedIndex = 0 }
                }

                Text {
                    text: "✕"
                    color: adaptiveColors.subtleTextColor
                    font.pixelSize: 14
                    visible: searchInput.text.length > 0

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = ""
                            searchInput.forceActiveFocus()
                        }
                    }
                }
            }
        }

        // Breadcrumb for folder navigation
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8
            visible: currentTab === "favorites" && searchQuery.length === 0 && currentFolderId !== ""

            Row {
                spacing: 4
                Text { text: "★"; color: adaptiveColors.textColor; font.pixelSize: 12 }
                Text {
                    text: "Favorites"
                    color: adaptiveColors.subtleTextColor
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.currentFolderId = ""; root.updateContent() }
                    }
                }
                Text { text: "›"; color: adaptiveColors.subtleTextColor; font.pixelSize: 12 }
                Text {
                    text: folders[currentFolderId] ? folders[currentFolderId].name : ""
                    color: adaptiveColors.textColor
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 80; height: 28; radius: 6
                color: "transparent"
                border.width: 1
                border.color: adaptiveColors.subtleTextColor
                Text { anchors.centerIn: parent; text: "← Back"; color: adaptiveColors.textColor; font.pixelSize: 11 }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.currentFolderId = ""; root.updateContent() }
                }
            }
        }

        // Tab bar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            spacing: 8
            visible: searchQuery.length === 0 && currentFolderId === ""

            Text {
                Layout.fillWidth: true
                text: currentTab === "favorites" ?
                      displayedApps.length + " item" + (displayedApps.length !== 1 ? "s" : "") :
                      displayedApps.length + " app" + (displayedApps.length !== 1 ? "s" : "")
                color: adaptiveColors.subtleTextColor
                font.pixelSize: 12
            }

            Row {
                spacing: 4
                Repeater {
                    model: [
                        { id: "favorites", icon: "★", label: "Favorites" },
                        { id: "all", icon: "☰", label: "All Apps" }
                    ]
                    Rectangle {
                        width: 100; height: 32; radius: 8
                        color: root.currentTab === modelData.id ?
                               Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.15) :
                               "transparent"
                        border.width: 1
                        border.color: Qt.rgba(adaptiveColors.subtleTextColor.r, adaptiveColors.subtleTextColor.g, adaptiveColors.subtleTextColor.b, 0.2)
                        RowLayout {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: modelData.icon; color: adaptiveColors.textColor; font.pixelSize: 14 }
                            Text { text: modelData.label; color: adaptiveColors.textColor; font.pixelSize: 11 }
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.currentTab = modelData.id; root.updateContent() }
                        }
                    }
                }
            }
        }

        // Search results header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8
            visible: searchQuery.length > 0
            Text {
                Layout.fillWidth: true
                text: displayedApps.length + " result" + (displayedApps.length !== 1 ? "s" : "") + " for \"" + searchQuery + "\""
                color: adaptiveColors.subtleTextColor
                font.pixelSize: 12
            }
        }

        // Main content area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Favorites Grid View
            Flickable {
                id: favoritesFlickable
                anchors.fill: parent
                visible: root.currentTab === "favorites"
                clip: true
                contentHeight: favoritesGrid.height
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                GridLayout {
                    id: favoritesGrid
                    width: parent.width
                    columns: 5
                    rowSpacing: 16
                    columnSpacing: 16

                    Repeater {
                        id: favoritesRepeater
                        model: displayedApps

                        Item {
                            id: gridItem
                            width: 88
                            height: 100
                            
                            property bool isSelected: root.selectedIndex === index
                            property bool isHovered: gridMouseArea.containsMouse
                            property bool isFolder: modelData.type === "folder"
                            property bool isDropTarget: root.dropTargetIndex === index && root.isDragging
                            property bool isBeingDragged: root.draggedIndex === index && root.isDragging
                            property var itemData: modelData

                            // Visual representation
                            Rectangle {
                                id: itemVisual
                                width: parent.width
                                height: parent.height
                                radius: 12
                                color: isDropTarget ? Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.25) :
                                       isSelected ? Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.15) :
                                       isHovered ? Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.08) :
                                       "transparent"
                                border.width: isSelected || isDropTarget ? 2 : 0
                                border.color: isDropTarget ? "#4CAF50" : adaptiveColors.textColor
                                opacity: isBeingDragged ? 0.3 : 1.0

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on opacity { NumberAnimation { duration: 100 } }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Item {
                                        width: 48; height: 48
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        // Folder icon with app preview grid
                                        Rectangle {
                                            anchors.fill: parent
                                            visible: isFolder
                                            radius: 10
                                            color: Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.15)
                                            border.width: 1
                                            border.color: Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.3)

                                            // 2x2 grid of app icons
                                            Grid {
                                                anchors.centerIn: parent
                                                columns: 2
                                                rows: 2
                                                spacing: 2
                                                
                                                property var folderIcons: {
                                                    if (!isFolder || !modelData.apps) return ["", "", "", ""]
                                                    var icons = []
                                                    var apps = modelData.apps
                                                    for (var i = 0; i < Math.min(4, apps.length); i++) {
                                                        var allApps = AppSearch.getAllApps()
                                                        for (var j = 0; j < allApps.length; j++) {
                                                            if (allApps[j].id === apps[i]) {
                                                                icons.push(allApps[j].icon)
                                                                break
                                                            }
                                                        }
                                                    }
                                                    // Pad with empty slots if less than 4 apps
                                                    while (icons.length < 4) icons.push("")
                                                    return icons
                                                }
                                                
                                                Repeater {
                                                    model: parent.folderIcons

                                                    delegate: Item {
                                                        required property string modelData
                                                        width: 20
                                                        height: 20
                                                        
                                                        Image {
                                                            anchors.fill: parent
                                                            anchors.margins: 1
                                                            source: modelData ? "image://icon/" + modelData : ""
                                                            sourceSize.width: 18
                                                            sourceSize.height: 18
                                                            fillMode: Image.PreserveAspectFit
                                                            smooth: true
                                                            visible: modelData !== ""
                                                        }
                                                        
                                                        Rectangle {
                                                            anchors.fill: parent
                                                            anchors.margins: 1
                                                            radius: 4
                                                            color: Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.1)
                                                            visible: modelData === ""
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // App icon
                                        Image {
                                            anchors.fill: parent
                                            visible: !isFolder
                                            source: isFolder ? "" : "image://icon/" + modelData.icon
                                            sourceSize.width: 48
                                            sourceSize.height: 48
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                        }
                                    }

                                    Text {
                                        text: modelData.name
                                        color: adaptiveColors.textColor
                                        font.pixelSize: 11
                                        font.weight: isFolder ? Font.Medium : Font.Normal
                                        width: 80
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            MouseArea {
                                id: gridMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor

                                property point pressPos: Qt.point(0, 0)
                                property bool potentialDrag: false

                                onEntered: {
                                    if (!root.keyboardMode) root.selectedIndex = index
                                }

                                onPressed: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        pressPos = Qt.point(mouse.x, mouse.y)
                                        potentialDrag = !isFolder && root.currentFolderId === ""
                                    }
                                }

                                onPositionChanged: function(mouse) {
                                    if (pressed && potentialDrag && !root.isDragging) {
                                        var dist = Math.sqrt(Math.pow(mouse.x - pressPos.x, 2) + Math.pow(mouse.y - pressPos.y, 2))
                                        if (dist > 15) {
                                            root.isDragging = true
                                            root.draggedIndex = index
                                            root.draggedItem = modelData
                                            dragProxy.visible = true
                                        }
                                    }
                                    if (root.isDragging) {
                                        var globalPos = mapToItem(root, mouse.x, mouse.y)
                                        dragProxy.x = globalPos.x - 44
                                        dragProxy.y = globalPos.y - 50
                                        
                                        // Find drop target
                                        var targetIdx = root.findItemAtPosition(globalPos.x, globalPos.y)
                                        if (targetIdx !== -1 && targetIdx !== root.draggedIndex) {
                                            root.dropTargetIndex = targetIdx
                                            root.dropTargetItem = displayedApps[targetIdx]
                                        } else {
                                            root.dropTargetIndex = -1
                                            root.dropTargetItem = null
                                        }
                                    }
                                }

                                onReleased: function(mouse) {
                                    var wasDragging = root.isDragging
                                    if (root.isDragging) {
                                        // Handle drop
                                        if (root.dropTargetIndex !== -1 && root.dropTargetIndex !== root.draggedIndex) {
                                            var target = displayedApps[root.dropTargetIndex]
                                            if (target.type === "folder") {
                                                // Drop onto folder - add to folder
                                                root.addAppToFolder(root.draggedItem.id, target.id)
                                            } else if (target.type === "app") {
                                                // Drop onto another app - create folder
                                                root.showFolderCreationDialog(root.draggedItem.id, target.id)
                                            }
                                        }
                                        
                                        // Reset drag state
                                        root.isDragging = false
                                        root.draggedIndex = -1
                                        root.draggedItem = null
                                        root.dropTargetIndex = -1
                                        root.dropTargetItem = null
                                        dragProxy.visible = false
                                    }
                                    potentialDrag = false
                                    
                                    // Handle click if wasn't dragging
                                    if (!wasDragging && mouse.button === Qt.LeftButton) {
                                        if (isFolder) {
                                            root.currentFolderId = modelData.id
                                            root.updateContent()
                                        } else {
                                            root.executeApp(modelData)
                                        }
                                    }
                                }

                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        root.contextMenuItem = modelData
                                        root.contextMenuPos = mapToItem(root, mouse.x, mouse.y)
                                        root.showContextMenu = true
                                    }
                                    // Left click is handled in onReleased to avoid firing after drag
                                }
                            }
                        }
                    }
                }

                // Empty state
                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: displayedApps.length === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "★"
                        font.pixelSize: 48
                        opacity: 0.3
                        color: adaptiveColors.textColor
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No favorite apps yet"
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 14
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Right-click an app to add it to favorites"
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 11
                    }
                }
            }

            // All Apps List View
            ListView {
                id: allAppsList
                anchors.fill: parent
                visible: root.currentTab === "all"
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: displayedApps
                currentIndex: root.selectedIndex
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    width: allAppsList.width
                    height: 56
                    radius: 8
                    color: root.selectedIndex === index ? Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.15) :
                           listMouseArea.containsMouse ? Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.08) :
                           "transparent"
                    border.width: root.selectedIndex === index ? 2 : 0
                    border.color: adaptiveColors.textColor

                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 12

                        Image {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            source: "image://icon/" + modelData.icon
                            sourceSize.width: 40
                            sourceSize.height: 40
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.name
                                color: adaptiveColors.textColor
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: modelData.comment || ""
                                color: adaptiveColors.subtleTextColor
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                width: parent.width
                                visible: text.length > 0
                            }
                        }

                        Text {
                            text: root.isFavorite(modelData.id) ? "★" : ""
                            color: adaptiveColors.textColor
                            font.pixelSize: 14
                            opacity: 0.6
                        }
                    }

                    MouseArea {
                        id: listMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onEntered: { if (!root.keyboardMode) root.selectedIndex = index }

                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) {
                                root.contextMenuItem = modelData
                                root.contextMenuPos = mapToItem(root, mouse.x, mouse.y)
                                root.showContextMenu = true
                            } else {
                                root.executeApp(modelData)
                            }
                        }
                    }
                }

                // Empty state for search
                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: displayedApps.length === 0 && searchQuery.length > 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "🔍"
                        font.pixelSize: 48
                        opacity: 0.3
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No applications found"
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 14
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Try a different search term"
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 11
                    }
                }
            }
        }

        // Help text
        Text {
            Layout.fillWidth: true
            text: currentTab === "favorites" && currentFolderId === "" ?
                  "Drag apps together to create folders • Right-click for options" :
                  searchQuery.length > 0 ? "↑↓ Navigate • Enter Open • Esc Clear" :
                  "↑↓ Navigate • Enter Open • Tab Switch • Esc Close"
            color: adaptiveColors.subtleTextColor
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.6
        }
    }

    // Drag proxy (floating item during drag)
    Rectangle {
        id: dragProxy
        width: 88
        height: 100
        radius: 12
        color: Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.2)
        visible: false
        z: 1000
        opacity: 0.9

        Column {
            anchors.centerIn: parent
            spacing: 8

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 48
                height: 48
                source: root.draggedItem ? "image://icon/" + root.draggedItem.icon : ""
                sourceSize.width: 48
                sourceSize.height: 48
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.draggedItem ? root.draggedItem.name : ""
                color: adaptiveColors.textColor
                font.pixelSize: 11
                width: 80
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }

    // Context Menu
    Rectangle {
        id: contextMenu
        visible: showContextMenu
        x: Math.min(contextMenuPos.x, root.width - width - 10)
        y: Math.min(contextMenuPos.y, root.height - height - 10)
        width: 200
        height: contextMenuColumn.height + 16
        radius: 12
        color: "#2a2e36"
        border.width: 1
        border.color: "#444a57"
        z: 2000

        Column {
            id: contextMenuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 2

            Repeater {
                id: contextMenuRepeater
                model: showContextMenu ? getContextMenuItems() : []
                
                // Reference to root for delegate access
                property Item appRoot: root

                delegate: Rectangle {
                    id: contextMenuDelegate
                    
                    // Access root through the Repeater parent
                    readonly property Item launcher: contextMenuRepeater.appRoot
                    
                    width: contextMenuColumn.width
                    height: 36
                    radius: 6
                    color: contextItemMouse.containsMouse ? Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.1) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: modelData.icon
                            font.pixelSize: 14
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: adaptiveColors.textColor
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: contextItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            var lnch = contextMenuDelegate.launcher
                            var item = lnch.contextMenuItem
                            var action = modelData.action
                            lnch.showContextMenu = false

                            switch (action) {
                                case "launch":
                                    lnch.executeApp(item)
                                    break
                                case "addFavorite":
                                    lnch.addToFavorites(item.id)
                                    break
                                case "removeFavorite":
                                    lnch.removeFromFavorites(item.id)
                                    break
                                case "removeFromFolder":
                                    lnch.removeAppFromFolder(item.id, lnch.currentFolderId)
                                    break
                                case "openFolder":
                                    lnch.currentFolderId = item.id
                                    lnch.updateContent()
                                    break
                                case "renameFolder":
                                    lnch.showRenameFolderDialog(item.id)
                                    break
                                case "deleteFolder":
                                    lnch.deleteFolder(item.id)
                                    break
                            }
                            lnch.contextMenuItem = null
                        }
                    }
                }
            }
        }
    }

    // Click outside context menu to close
    MouseArea {
        anchors.fill: parent
        visible: showContextMenu
        z: 1999
        onClicked: {
            showContextMenu = false
            contextMenuItem = null
        }
    }

    // Folder Dialog
    property string pendingFolderApp1: ""
    property string pendingFolderApp2: ""
    property bool showFolderDialog: false
    property string folderDialogMode: "create"
    property string renamingFolderId: ""

    function showFolderCreationDialog(app1Id, app2Id) {
        pendingFolderApp1 = app1Id
        pendingFolderApp2 = app2Id
        folderDialogMode = "create"
        showFolderDialog = true
        folderNameInput.text = ""
        folderNameInput.forceActiveFocus()
    }

    function showRenameFolderDialog(folderId) {
        renamingFolderId = folderId
        folderDialogMode = "rename"
        showFolderDialog = true
        folderNameInput.text = folders[folderId] ? folders[folderId].name : ""
        folderNameInput.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        visible: root.showFolderDialog
        color: Qt.rgba(0, 0, 0, 0.6)
        z: 3000

        MouseArea {
            anchors.fill: parent
            onClicked: root.showFolderDialog = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 320
            height: 180
            radius: 16
            color: "#23272e"
            border.width: 2
            border.color: "#444a57"

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                Text {
                    text: root.folderDialogMode === "create" ? "Create New Folder" : "Rename Folder"
                    color: adaptiveColors.textColor
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }

                Column {
                    spacing: 8
                    Layout.fillWidth: true

                    Text {
                        text: "Folder Name:"
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 12
                    }

                    Rectangle {
                        width: parent.width
                        height: 40
                        radius: 8
                        color: "#1a1d23"
                        border.width: 1
                        border.color: "#444a57"

                        TextInput {
                            id: folderNameInput
                            anchors.fill: parent
                            anchors.margins: 12
                            color: adaptiveColors.textColor
                            font.pixelSize: 14
                            selectByMouse: true
                            clip: true

                            Keys.onReturnPressed: {
                                if (text.length > 0) {
                                    if (root.folderDialogMode === "create") {
                                        root.createFolder(text, root.pendingFolderApp1, root.pendingFolderApp2)
                                    } else {
                                        root.renameFolder(root.renamingFolderId, text)
                                    }
                                    text = ""
                                    root.showFolderDialog = false
                                }
                            }

                            Keys.onEscapePressed: {
                                root.showFolderDialog = false
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Row {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 36
                        radius: 8
                        color: cancelBtnMouse.containsMouse ? "#333740" : "#23272e"
                        border.width: 1
                        border.color: "#444a57"

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: adaptiveColors.textColor
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: cancelBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.showFolderDialog = false
                                folderNameInput.text = ""
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 36
                        radius: 8
                        color: createBtnMouse.containsMouse ?
                               Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.25) :
                               Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.15)
                        border.width: 1
                        border.color: adaptiveColors.textColor

                        Text {
                            anchors.centerIn: parent
                            text: root.folderDialogMode === "create" ? "Create" : "Rename"
                            color: adaptiveColors.textColor
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: createBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (folderNameInput.text.length > 0) {
                                    if (root.folderDialogMode === "create") {
                                        root.createFolder(folderNameInput.text, root.pendingFolderApp1, root.pendingFolderApp2)
                                    } else {
                                        root.renameFolder(root.renamingFolderId, folderNameInput.text)
                                    }
                                    folderNameInput.text = ""
                                    root.showFolderDialog = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

