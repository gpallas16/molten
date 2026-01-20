 pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

/**
 * Notification service - based on Ambxst implementation
 * Handles notification server, persistence, grouping, and popup management
 */
Singleton {
    id: root

    // ═══════════════════════════════════════════════════════════════
    // NOTIFICATION OBJECT COMPONENT
    // ═══════════════════════════════════════════════════════════════
    
    component Notif: QtObject {
        required property int id
        property Notification notification
        property list<var> actions: notification?.actions.map(action => ({
            "identifier": action.identifier,
            "text": action.text
        })) ?? []
        property bool popup: false
        
        // Captured values to avoid binding issues
        property string appIcon: ""
        property string appName: ""
        property string body: ""
        property string image: ""
        property string summary: ""
        property double time
        property int urgency: NotificationUrgency.Normal
        property Timer timer
        
        // Cache for images
        property string cachedAppIcon: ""
        property string cachedImage: ""
        property bool isCached: false

        onNotificationChanged: {
            if (notification) {
                appIcon = notification.appIcon ?? ""
                appName = notification.appName ?? ""
                body = notification.body ?? ""
                image = notification.image ?? ""
                summary = notification.summary ?? ""
                urgency = notification.urgency ?? NotificationUrgency.Normal

                // Cache images from URLs
                if (appIcon && !appIcon.startsWith("data:")) {
                    root.cacheImageAsBase64(appIcon, function(cachedData) {
                        cachedAppIcon = cachedData
                    })
                }
                if (image && !image.startsWith("data:")) {
                    root.cacheImageAsBase64(image, function(cachedData) {
                        cachedImage = cachedData
                    })
                }

                // Listen for app-requested close
                notification.closed.connect(function(reason) {
                    if (reason === 3) { // CloseRequested
                        root.discardNotification(id)
                    }
                })
            }
        }

        Component.onDestruction: {
            if (timer) {
                timer.stop()
                timer.destroy()
                timer = null
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // NOTIFICATION TIMER COMPONENT
    // ═══════════════════════════════════════════════════════════════
    
    component NotifTimer: Timer {
        required property int id
        property int originalInterval: 8000  // 8 seconds
        property bool isPaused: false
        property real startTime: Date.now()

        interval: originalInterval
        running: !isPaused

        function pause() {
            if (!isPaused) {
                isPaused = true
                stop()
            }
        }

        function resume() {
            if (isPaused) {
                isPaused = false
                interval = originalInterval
                startTime = Date.now()
                start()
            }
        }

        function triggerTimeout() {
            root.timeoutNotification(id)
            destroy()
        }

        onTriggered: triggerTimeout()

        onRunningChanged: {
            if (running) {
                startTime = Date.now()
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // PROPERTIES
    // ═══════════════════════════════════════════════════════════════
    
    property bool silent: false
    property bool doNotDisturb: false
    property list<Notif> list: []
    property var popupList: list.filter(notif => notif.popup)
    property bool popupInhibited: silent || doNotDisturb
    property var latestTimeForApp: ({})
    
    // Popup notifications for inline bar display
    property var popupNotifications: popupList
    
    // All notifications for notification center
    property var notifications: list

    Component {
        id: notifComponent
        Notif {}
    }
    
    Component {
        id: notifTimerComponent
        NotifTimer {}
    }

    // ═══════════════════════════════════════════════════════════════
    // PERSISTENCE
    // ═══════════════════════════════════════════════════════════════
    
    FileView {
        id: notifFileView
        path: Quickshell.dataPath("notifications.json")
        onLoaded: loadNotifications()
    }

    function notifToJSON(notif) {
        return {
            "id": notif.id,
            "actions": notif.actions,
            "appIcon": notif.appIcon,
            "appName": notif.appName,
            "body": notif.body,
            "image": notif.image,
            "summary": notif.summary,
            "time": notif.time,
            "urgency": notif.urgency,
            "cachedAppIcon": notif.cachedAppIcon,
            "cachedImage": notif.cachedImage,
            "isCached": notif.isCached
        }
    }

    function stringifyList(list) {
        return JSON.stringify(list.map(notif => notifToJSON(notif)), null, 2)
    }

    function jsonToNotif(json) {
        return notifComponent.createObject(root, {
            "id": json.id,
            "actions": json.actions,
            "appIcon": json.cachedAppIcon || json.appIcon,
            "appName": json.appName,
            "body": json.body,
            "image": json.cachedImage || json.image,
            "summary": json.summary,
            "time": json.time,
            "urgency": json.urgency,
            "cachedAppIcon": json.cachedAppIcon || "",
            "cachedImage": json.cachedImage || "",
            "isCached": true,
            "popup": false
        })
    }

    function saveNotifications() {
        const limitedList = limitNotificationsPerSummary(root.list)
        notifFileView.setText(stringifyList(limitedList))
    }

    function limitNotificationsPerSummary(notifications) {
        var groups = {}

        notifications.forEach(notif => {
            const key = notif.appName + '|' + (notif.summary || '')
            if (!groups[key]) {
                groups[key] = []
            }
            groups[key].push(notif)
        })

        const limitedNotifications = []
        for (const key in groups) {
            const group = groups[key]
            group.sort((a, b) => b.time - a.time)
            limitedNotifications.push(...group.slice(0, 5))
        }

        return limitedNotifications
    }

    function loadNotifications() {
        try {
            const data = JSON.parse(notifFileView.text())
            root.list = data.map(jsonToNotif)
            let maxId = 0
            root.list.forEach(notif => {
                if (notif.id > maxId)
                    maxId = notif.id
            })
            root.idOffset = maxId + 1
        } catch (e) {
            console.log("No saved notifications or error loading:", e)
            root.list = []
            root.idOffset = 0
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // GROUPING
    // ═══════════════════════════════════════════════════════════════
    
    onListChanged: {
        root.list.forEach(notif => {
            if (!root.latestTimeForApp[notif.appName] || notif.time > root.latestTimeForApp[notif.appName]) {
                root.latestTimeForApp[notif.appName] = Math.max(root.latestTimeForApp[notif.appName] || 0, notif.time)
            }
        })
        Object.keys(root.latestTimeForApp).forEach(appName => {
            if (!root.list.some(notif => notif.appName === appName)) {
                delete root.latestTimeForApp[appName]
            }
        })
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => {
            return groups[b].time - groups[a].time
        })
    }

    function groupsForList(list) {
        const groups = {}
        list.forEach((notif) => {
            if (!notif || !notif.appName || (!notif.summary && !notif.body)) {
                return
            }

            if (!groups[notif.appName]) {
                groups[notif.appName] = {
                    appName: notif.appName,
                    appIcon: notif.appIcon,
                    notifications: [],
                    time: 0,
                    totalCount: 0
                }
            }
            groups[notif.appName].notifications.push(notif)
            groups[notif.appName].totalCount++
            groups[notif.appName].time = latestTimeForApp[notif.appName] || notif.time
        })

        return groups
    }

    property var groupsByAppName: groupsForList(root.list)
    property var popupGroupsByAppName: groupsForList(root.popupList)
    property var appNameList: appNameListForGroups(root.groupsByAppName)
    property var popupAppNameList: appNameListForGroups(root.popupGroupsByAppName)

    // ═══════════════════════════════════════════════════════════════
    // NOTIFICATION SERVER
    // ═══════════════════════════════════════════════════════════════
    
    property int idOffset: 0
    
    signal initDone
    signal notify(notification: var)
    signal discard(id: var)
    signal discardAll
    signal timeout(id: var)
    signal timeoutWithAnimation(id: var)

    NotificationServer {
        id: notifServer
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: notification => {
            if (!notification || (!notification.summary && !notification.body)) {
                return
            }

            notification.tracked = true
            const newNotifObject = notifComponent.createObject(root, {
                "id": notification.id + root.idOffset,
                "notification": notification,
                "time": Date.now()
            })

            Qt.callLater(() => {
                root.list = [...root.list, newNotifObject]
                saveNotifications()
            })

            // Popup handling - show in bar if not inhibited
            if (!root.popupInhibited) {
                newNotifObject.popup = true
                newNotifObject.timer = notifTimerComponent.createObject(root, {
                    "id": newNotifObject.id,
                    "interval": notification.expireTimeout < 0 ? 8000 : Math.min(notification.expireTimeout, 8000)
                })
            }

            root.notify(newNotifObject)
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // NOTIFICATION ACTIONS
    // ═══════════════════════════════════════════════════════════════
    
    function discardNotification(id) {
        const index = root.list.findIndex(notif => notif.id === id)
        const notifServerIndex = notifServer.trackedNotifications.values.findIndex(notif => notif.id + root.idOffset === id)
        if (index !== -1) {
            root.list.splice(index, 1)
            triggerListChange()
            saveNotifications()
        }
        if (notifServerIndex !== -1) {
            notifServer.trackedNotifications.values[notifServerIndex].dismiss()
        }
        root.discard(id)
    }

    function discardNotifications(ids) {
        if (!ids || ids.length === 0) return

        var idsMap = {}
        ids.forEach(id => { idsMap[id] = true })

        const newList = root.list.filter(notif => !idsMap[notif.id])
        const removedCount = root.list.length - newList.length

        if (removedCount > 0) {
            root.list = newList
            triggerListChange()
            saveNotifications()
        }

        ids.forEach(id => {
            const notifServerIndex = notifServer.trackedNotifications.values.findIndex(notif => notif.id + root.idOffset === id)
            if (notifServerIndex !== -1) {
                notifServer.trackedNotifications.values[notifServerIndex].dismiss()
            }
            root.discard(id)
        })
    }

    function discardAllNotifications() {
        root.list = []
        triggerListChange()
        saveNotifications()
        notifServer.trackedNotifications.values.forEach(notif => {
            notif.dismiss()
        })
        root.discardAll()
    }

    Timer {
        id: timeoutAnimationTimer
        interval: 350
        running: false
        repeat: false
        property int notificationId: -1
        onTriggered: {
            const index = root.list.findIndex(notif => notif.id === notificationId)
            if (index !== -1 && root.list[index] != null)
                root.list[index].popup = false
            root.timeout(notificationId)
        }
    }

    function timeoutNotification(id) {
        root.timeoutWithAnimation(id)
        timeoutAnimationTimer.notificationId = id
        timeoutAnimationTimer.restart()
    }

    function timeoutAll() {
        root.popupList.forEach(notif => {
            root.timeout(notif.id)
        })
        root.popupList.forEach(notif => {
            notif.popup = false
        })
    }

    function attemptInvokeAction(id, notifIdentifier, autoDiscard = true) {
        const notifServerIndex = notifServer.trackedNotifications.values.findIndex(notif => notif.id + root.idOffset === id)
        if (notifServerIndex !== -1) {
            const notifServerNotif = notifServer.trackedNotifications.values[notifServerIndex]
            const action = notifServerNotif.actions.find(action => action.identifier === notifIdentifier)
            if (action) action.invoke()
        }
        if (autoDiscard) {
            root.discardNotification(id)
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // TIMER CONTROL
    // ═══════════════════════════════════════════════════════════════
    
    function pauseGroupTimers(appName) {
        root.popupList.forEach(notif => {
            if (notif.appName === appName && notif.timer) {
                notif.timer.pause()
            }
        })
    }

    function resumeGroupTimers(appName) {
        root.popupList.forEach(notif => {
            if (notif.appName === appName && notif.timer) {
                notif.timer.resume()
            }
        })
    }

    function pauseAllTimers() {
        root.popupList.forEach(notif => {
            if (notif.timer) {
                notif.timer.pause()
            }
        })
    }

    function resumeAllTimers() {
        root.popupList.forEach(notif => {
            if (notif.timer) {
                notif.timer.resume()
            }
        })
    }

    function hideAllPopups() {
        root.popupList.forEach(notif => {
            notif.popup = false
            if (notif.timer) {
                notif.timer.stop()
                notif.timer.destroy()
                notif.timer = null
            }
        })
    }

    function triggerListChange() {
        root.list = root.list.slice(0)
    }

    // ═══════════════════════════════════════════════════════════════
    // IMAGE CACHING
    // ═══════════════════════════════════════════════════════════════
    
    property int activeXhrCount: 0
    property int maxConcurrentXhr: 3

    function cacheImageAsBase64(imageUrl, callback) {
        if (!imageUrl || imageUrl.startsWith("data:")) {
            callback(imageUrl)
            return
        }

        if (!imageUrl.startsWith("http://") && !imageUrl.startsWith("https://")) {
            callback(imageUrl)
            return
        }

        if (imageUrl.length > 2048) {
            callback(imageUrl)
            return
        }

        if (activeXhrCount >= maxConcurrentXhr) {
            callback(imageUrl)
            return
        }

        activeXhrCount++
        var xhr = new XMLHttpRequest()
        xhr.open("GET", imageUrl, true)
        xhr.responseType = "arraybuffer"
        xhr.timeout = 5000

        var cleanupXhr = function() {
            activeXhrCount--
            xhr = null
        }

        xhr.onload = function() {
            if (xhr.status === 200 && xhr.response) {
                try {
                    var arrayBuffer = xhr.response
                    var bytes = new Uint8Array(arrayBuffer)
                    var binary = ''
                    var len = Math.min(bytes.byteLength, 1024 * 1024)
                    for (var i = 0; i < len; i++) {
                        binary += String.fromCharCode(bytes[i])
                    }
                    var base64 = btoa(binary)

                    var mimeType = "image/png"
                    var lowerUrl = imageUrl.toLowerCase()
                    if (lowerUrl.includes(".jpg") || lowerUrl.includes(".jpeg")) {
                        mimeType = "image/jpeg"
                    } else if (lowerUrl.includes(".gif")) {
                        mimeType = "image/gif"
                    } else if (lowerUrl.includes(".webp")) {
                        mimeType = "image/webp"
                    }

                    callback("data:" + mimeType + ";base64," + base64)
                } catch (e) {
                    callback(imageUrl)
                }
            } else {
                callback(imageUrl)
            }
            cleanupXhr()
        }

        xhr.onerror = function() {
            callback(imageUrl)
            cleanupXhr()
        }

        xhr.ontimeout = function() {
            callback(imageUrl)
            cleanupXhr()
        }

        xhr.send()
    }

    Component.onCompleted: {
        notifFileView.reload()
        root.initDone()
    }
}
