import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import ".."

Item {
    id: root
    implicitWidth: 520
    implicitHeight: 600

    signal closeRequested()

    property string currentTab: "favorites"
    property string searchQuery: ""
    property int selectedIndex: -1
    property bool keyboardMode: false
    property var favoriteApps: ({})
    property var folders: ({})
    property string currentFolderId: ""
    property bool showFolderDialog: false
    property string folderDialogMode: "create"
    property string appToAddToFolder: ""

    AdaptiveColors {
        id: adaptiveColors
        region: "notch"
    }

    Component.onCompleted: {
        loadFavorites()
        updateContent()
        searchInput.forceActiveFocus()
    }

    function loadFavorites() {
        // TODO: Load from persistent storage
    }

    function saveFavorites() {
        // TODO: Save to persistent storage
    }

    function createFolder(name) {
        var folderId = "folder_" + Date.now()
        var newFolders = Object.assign({}, folders)
        newFolders[folderId] = { name: name, apps: [] }
        folders = newFolders
        saveFavorites()
    }

    function deleteFolder(folderId) {
        var newFolders = Object.assign({}, folders)
        if (newFolders[folderId] && newFolders[folderId].apps) {
            for (var i = 0; i < newFolders[folderId].apps.length; i++) {
                favoriteApps[newFolders[folderId].apps[i]] = true
            }
        }
        delete newFolders[folderId]
        folders = newFolders
        if (currentFolderId === folderId) currentFolderId = ""
        saveFavorites()
        updateContent()
    }

    function addAppToFolder(appId, folderId) {
        var newFolders = Object.assign({}, folders)
        if (!newFolders[folderId]) return
        for (var key in newFolders) {
            var idx = newFolders[key].apps.indexOf(appId)
            if (idx !== -1) newFolders[key].apps.splice(idx, 1)
        }
        if (!newFolders[folderId].apps.includes(appId)) {
            newFolders[folderId].apps.push(appId)
        }
        folders = newFolders
        saveFavorites()
        updateContent()
    }

    function removeAppFromFolder(appId) {
        var newFolders = Object.assign({}, folders)
        for (var key in newFolders) {
            var idx = newFolders[key].apps.indexOf(appId)
            if (idx !== -1) newFolders[key].apps.splice(idx, 1)
        }
        folders = newFolders
        favoriteApps[appId] = true
        saveFavorites()
        updateContent()
    }

    function isAppInFolder(appId) {
        for (var key in folders) {
            if (folders[key].apps.indexOf(appId) !== -1) return key
        }
        return null
    }

    function toggleFavorite(appId) {
        var newFavorites = Object.assign({}, favoriteApps)
        if (newFavorites[appId]) delete newFavorites[appId]
        else newFavorites[appId] = true
        favoriteApps = newFavorites
        saveFavorites()
        updateContent()
    }

    function isFavorite(appId) {
        return favoriteApps[appId] === true
    }

    onSearchQueryChanged: {
        if (searchQuery.length > 0) {
            currentTab = "all"
            searchInput.forceActiveFocus()
        } else {
            currentTab = "favorites"
        }
        updateContent()
    }

    function updateContent() {
        if (searchQuery.length > 0) updateSearchResults()
        else if (currentTab === "favorites") updateFavorites()
        else updateAllApps()
    }

    property var displayedApps: []

    function updateFavorites() {
        var allApps = AppSearch.getAllApps()
        var items = []
        if (currentFolderId === "") {
            for (var folderId in folders) {
                items.push({
                    type: "folder",
                    id: folderId,
                    name: folders[folderId].name,
                    icon: "folder",
                    appCount: folders[folderId].apps.length
                })
            }
            for (var i = 0; i < allApps.length; i++) {
                if (favoriteApps[allApps[i].id] && !isAppInFolder(allApps[i].id)) {
                    items.push(Object.assign({}, allApps[i], { type: "app" }))
                }
            }
        } else {
            var folder = folders[currentFolderId]
            if (folder) {
                for (var j = 0; j < folder.apps.length; j++) {
                    for (var k = 0; k < allApps.length; k++) {
                        if (allApps[k].id === folder.apps[j]) {
                            items.push(Object.assign({}, allApps[k], { type: "app" }))
                            break
                        }
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

    Keys.onPressed: function(event) {
        keyboardMode = true
        if (event.key === Qt.Key_Escape) {
            if (searchQuery.length > 0) searchQuery = ""
            else root.closeRequested()
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

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

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
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
                        model: displayedApps
                        Item {
                            width: 88; height: 100
                            property bool isSelected: root.selectedIndex === index
                            property bool isHovered: favGridMouse.containsMouse
                            property bool isFolder: modelData.type === "folder"

                            Rectangle {
                                anchors.fill: parent; anchors.margins: -4; radius: 12
                                color: parent.isSelected ? Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.15) :
                                       parent.isHovered ? Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.08) :
                                       "transparent"
                                border.width: parent.isSelected ? 2 : 0
                                border.color: adaptiveColors.textColor
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Column {
                                anchors.centerIn: parent; spacing: 8; z: 1
                                Item {
                                    width: 48; height: 48
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    Rectangle {
                                        anchors.fill: parent; visible: isFolder; radius: 8
                                        color: Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.2)
                                        border.width: 2
                                        border.color: adaptiveColors.textColor
                                        Column {
                                            anchors.centerIn: parent; spacing: 2
                                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "📁"; font.pixelSize: 24 }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: modelData.appCount || 0
                                                color: adaptiveColors.textColor
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }

                                    Image {
                                        anchors.fill: parent; visible: !isFolder
                                        source: isFolder ? "" : "image://icon/" + modelData.icon
                                        sourceSize.width: 48; sourceSize.height: 48
                                        fillMode: Image.PreserveAspectFit; smooth: true
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

                            MouseArea {
                                id: favGridMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                
                                onEntered: { if (!root.keyboardMode) root.selectedIndex = index }
                                
                                onClicked: {
                                    if (isFolder) {
                                        root.currentFolderId = modelData.id
                                        root.updateContent()
                                    } else {
                                        root.executeApp(modelData)
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: 88; height: 100
                        visible: root.currentFolderId === ""
                        Rectangle {
                            anchors.fill: parent; anchors.margins: -4; radius: 12
                            color: newFolderMouse.containsMouse ? Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.08) : "transparent"
                            border.width: 2
                            border.color: Qt.rgba(adaptiveColors.subtleTextColor.r, adaptiveColors.subtleTextColor.g, adaptiveColors.subtleTextColor.b, 0.3)
                            Column {
                                anchors.centerIn: parent; spacing: 8
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "➕"; font.pixelSize: 24; opacity: 0.5; color: adaptiveColors.textColor }
                                Text { text: "New Folder"; color: adaptiveColors.subtleTextColor; font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                            MouseArea {
                                id: newFolderMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.folderDialogMode = "create"; root.showFolderDialog = true }
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent; spacing: 12
                    visible: displayedApps.length === 0
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "★"; font.pixelSize: 48; opacity: 0.3; color: adaptiveColors.textColor }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No favorite apps yet"; color: adaptiveColors.subtleTextColor; font.pixelSize: 14 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Right-click an app to add it to favorites"; color: adaptiveColors.subtleTextColor; font.pixelSize: 11 }
                }
            }

            ListView {
                id: allAppsList
                anchors.fill: parent
                visible: root.currentTab === "all"
                clip: true; spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: displayedApps
                currentIndex: root.selectedIndex
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    width: allAppsList.width; height: 56; radius: 8
                    color: root.selectedIndex === index ? Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.15) :
                           allListMouse.containsMouse ? Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.08) :
                           "transparent"
                    border.width: root.selectedIndex === index ? 2 : 0
                    border.color: adaptiveColors.textColor
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 8; spacing: 12
                        Image {
                            Layout.preferredWidth: 40; Layout.preferredHeight: 40
                            source: "image://icon/" + modelData.icon
                            sourceSize.width: 40; sourceSize.height: 40
                            fillMode: Image.PreserveAspectFit; smooth: true
                        }
                        Column {
                            Layout.fillWidth: true; spacing: 2
                            Text { text: modelData.name; color: adaptiveColors.textColor; font.pixelSize: 13; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width }
                            Text { text: modelData.comment || ""; color: adaptiveColors.subtleTextColor; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width; visible: text.length > 0 }
                        }
                        Text {
                            text: root.isFavorite(modelData.id) ? "★" : "☆"
                            color: root.isFavorite(modelData.id) ? adaptiveColors.textColor : adaptiveColors.subtleTextColor
                            font.pixelSize: 16
                        }
                    }

                    MouseArea {
                        id: allListMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        
                        onEntered: { if (!root.keyboardMode) root.selectedIndex = index }
                        onClicked: { root.executeApp(modelData) }
                    }
                }

                Column {
                    anchors.centerIn: parent; spacing: 12
                    visible: displayedApps.length === 0 && searchQuery.length > 0
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "🔍"; font.pixelSize: 48; opacity: 0.3 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No applications found"; color: adaptiveColors.subtleTextColor; font.pixelSize: 14 }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Try a different search term"; color: adaptiveColors.subtleTextColor; font.pixelSize: 11 }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: searchQuery.length > 0 ? "↑↓ Navigate • Enter Open • Esc Clear" :
                  "↑↓ Navigate • Enter Open • Tab Switch • Esc Close"
            color: adaptiveColors.subtleTextColor
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.6
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.showFolderDialog
        color: Qt.rgba(0, 0, 0, 0.6)
        z: 1000
        MouseArea { anchors.fill: parent; onClicked: root.showFolderDialog = false }

        Rectangle {
            anchors.centerIn: parent
            width: 320
            height: folderDialogMode === "create" ? 180 : 240
            radius: 16
            color: "#23272e"
            border.width: 2
            border.color: "#444a57"
            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 20; spacing: 16
                Text { text: root.folderDialogMode === "create" ? "Create New Folder" : "Add to Folder"; color: adaptiveColors.textColor; font.pixelSize: 16; font.weight: Font.Medium }

                Column {
                    visible: root.folderDialogMode === "create"
                    spacing: 8
                    Layout.fillWidth: true
                    Text { text: "Folder Name:"; color: adaptiveColors.subtleTextColor; font.pixelSize: 12 }
                    Rectangle {
                        width: parent.width; height: 40; radius: 8; color: "#1a1d23"; border.width: 1; border.color: "#444a57"
                        TextInput {
                            id: folderNameInput
                            anchors.fill: parent; anchors.margins: 12
                            color: adaptiveColors.textColor; font.pixelSize: 14; selectByMouse: true; clip: true
                            Keys.onReturnPressed: {
                                if (text.length > 0) {
                                    root.createFolder(text)
                                    text = ""
                                    root.showFolderDialog = false
                                    root.updateContent()
                                }
                            }
                        }
                    }
                }

                Column {
                    visible: root.folderDialogMode === "addTo"
                    spacing: 8
                    Layout.fillWidth: true
                    Text { text: "Select Folder:"; color: adaptiveColors.subtleTextColor; font.pixelSize: 12 }
                    ListView {
                        width: parent.width; height: 120; clip: true; spacing: 4
                        model: {
                            var folderList = []
                            for (var key in root.folders) {
                                folderList.push({ id: key, name: root.folders[key].name })
                            }
                            return folderList
                        }
                        delegate: Rectangle {
                            width: parent.width; height: 36; radius: 6
                            color: folderItemMouse.containsMouse ? Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.1) : "transparent"
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 8; spacing: 8
                                Text { text: "📁"; font.pixelSize: 16 }
                                Text { text: modelData.name; color: adaptiveColors.textColor; font.pixelSize: 13; Layout.fillWidth: true }
                            }
                            MouseArea {
                                id: folderItemMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.addAppToFolder(root.appToAddToFolder, modelData.id)
                                    root.showFolderDialog = false
                                    root.appToAddToFolder = ""
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Row {
                    Layout.fillWidth: true; spacing: 8
                    Rectangle {
                        width: (parent.width - 8) / 2; height: 36; radius: 8
                        color: cancelBtnMouse.containsMouse ? "#333740" : "#23272e"
                        border.width: 1; border.color: "#444a57"
                        Text { anchors.centerIn: parent; text: "Cancel"; color: adaptiveColors.textColor; font.pixelSize: 13 }
                        MouseArea {
                            id: cancelBtnMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.showFolderDialog = false; folderNameInput.text = "" }
                        }
                    }
                    Rectangle {
                        visible: root.folderDialogMode === "create"
                        width: (parent.width - 8) / 2; height: 36; radius: 8
                        color: createBtnMouse.containsMouse ? Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.25) :
                               Qt.rgba(adaptiveColors.textColor.r, adaptiveColors.textColor.g, adaptiveColors.textColor.b, 0.15)
                        border.width: 1; border.color: adaptiveColors.textColor
                        Text { anchors.centerIn: parent; text: "Create"; color: adaptiveColors.textColor; font.pixelSize: 13; font.weight: Font.Medium }
                        MouseArea {
                            id: createBtnMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (folderNameInput.text.length > 0) {
                                    root.createFolder(folderNameInput.text)
                                    folderNameInput.text = ""
                                    root.showFolderDialog = false
                                    root.updateContent()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

