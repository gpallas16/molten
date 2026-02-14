import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../globals" as Root
import "../../globals"
import "../../services"
import "../../services/notification_utils.js" as NotificationUtils
import ".."
import "../behavior"
import "../transforms"
import "../widgets"

/**
 * MainBar - Dynamic Island style notch bar
 * 
 * Pure panel UI - content rendered directly in the panel window.
 */
Item {
    id: notchContainer

    // Size from panel backdrop
    implicitWidth: panelBackdrop.implicitWidth
    implicitHeight: panelBackdrop.implicitHeight
    width: implicitWidth
    height: implicitHeight
    
    /** Current margin from screen edge */
    readonly property real barMargin: 6
    
    /** Screen dimensions - must be set by parent */
    property int screenWidth: 1920
    property int screenHeight: 1080

    // ═══════════════════════════════════════════════════════════════
    // BEHAVIOR MODE - Controls auto-hide behavior
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * Behavior mode for the bar
     * @type {string} "floating" | "discrete" | "hidden" | "dynamic"
     */
    property string mode: "dynamic"
    
    /** Whether there are active windows (affects dynamic mode) */
    property bool hasActiveWindows: false
    
    /** Whether this bar is active (for disabling AdaptiveColors in fullscreen) */
    property bool active: true

    /** Parent window (used for tray menus) */
    property var parentWindow: null

    // External hover tracking (from full-width bottom zone)
    property bool externalHover: false
    
    // Internal hover tracking (combines external and bar hover)
    property bool _realHover: externalHover || _barHover
    property bool _barHover: false
    
    /**
     * Temporarily show the bar (e.g., on activity/events)
     */
    function showTemporarily() {
        behavior.showTemporarily()
    }
    
    // Behavior controller - handles all visibility/state logic
    BarBehavior {
        id: behavior
        debugName: "MainBar"
        mode: notchContainer.mode
        barHovered: notchContainer._realHover
        popupActive: notchContainer.notificationPopupActive || notchContainer.volumeOverlayActive || notchContainer.brightnessOverlayActive || notchContainer.trayMenuActive || notchContainer.toolbarPopupActive || notchContainer.livePopupActive || notchContainer.appPopupActive
        isExpanded: notchContainer.isExpanded
        hasActiveWindows: notchContainer.hasActiveWindows
        hideDelay: 1000
    }
    
    // Computed from behavior - toolbar popup forces normal mode
    readonly property bool compactMode: (toolbarPopupActive || livePopupActive || appPopupActive) ? false : behavior.isCompact
    readonly property bool showBar: behavior.barVisible
    readonly property string internalState: behavior.internalState

    // ═══════════════════════════════════════════════════════════════
    // DERIVED STATE - Computed from compactMode
    // ═══════════════════════════════════════════════════════════════
    
    /** @deprecated Use compactMode directly - kept for compatibility */
    readonly property bool discreteMode: compactMode
    /** True when not in compact mode - full bar appearance */
    readonly property bool floatingMode: !compactMode
    
    // ═══════════════════════════════════════════════════════════════
    // INTERNAL VIEW STATE - Screen navigation
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * Currently displayed screen/view
     * @type {string} "default" | "launcher" | "live" | "notifications" | "toolbar" | "power"
     */
    property string currentView: "default"
    
    /** True when showing an expanded screen (not default collapsed view) */
    property bool isExpanded: currentView !== "default"
    
    // ═══════════════════════════════════════════════════════════════
    // POPUP STATES - Temporary overlays that expand the bar
    // ═══════════════════════════════════════════════════════════════
    
    /** True when notification popup is showing (auto-set from Notifications service) */
    property bool notificationPopupActive: Notifications.popupList.length > 0
    
    /** True when volume overlay is visible (triggered by showVolumeOverlay()) */
    property bool volumeOverlayActive: false
    
    /** True when brightness overlay is visible (triggered by showBrightnessOverlay()) */
    property bool brightnessOverlayActive: false
    
    /** Combined state: true when bar is expanded for any reason */
    readonly property bool screenNotchOpen: isExpanded || volumeOverlayActive || brightnessOverlayActive || notificationPopupActive

    /** System tray menu active (keeps bar visible) */
    property bool trayMenuActive: false

    /** Active tray item id */
    property string activeTrayItem: ""
    
    // ═══════════════════════════════════════════════════════════════
    // SIGNALS - Communication with parent
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * Emitted when mouse hover state changes on the bar
     * @param {bool} hovering - True when mouse is over the bar
     * 
     * Parent should connect this to BarBehavior.barHovered
     */
    signal barHoverChanged(bool hovering)
    
    /**
     * Emitted when an expanded view requests to close
     * 
     * Parent can use this to update its state when bar collapses
     */
    signal closeRequested()
    
    /**
     * Emitted when popup state changes (notifications or volume)
     * @param {bool} active - True when any popup is active
     * 
     * Parent should use this to force floating mode during popups
     */
    signal popupActiveChanged(bool active)
    
    // Auto-emit popup changes to parent
    onNotificationPopupActiveChanged: popupActiveChanged(notificationPopupActive || volumeOverlayActive || brightnessOverlayActive || trayMenuActive)
    onVolumeOverlayActiveChanged: popupActiveChanged(notificationPopupActive || volumeOverlayActive || brightnessOverlayActive || trayMenuActive)
    onBrightnessOverlayActiveChanged: popupActiveChanged(notificationPopupActive || volumeOverlayActive || brightnessOverlayActive || trayMenuActive)
    onTrayMenuActiveChanged: popupActiveChanged(notificationPopupActive || volumeOverlayActive || brightnessOverlayActive || trayMenuActive)
    
    // ═══════════════════════════════════════════════════════════════
    // PUBLIC METHODS
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * Show volume overlay with auto-hide timer
     * 
     * Called externally (e.g., on scroll wheel) to display GNOME-style
     * volume feedback. Auto-hides after 2 seconds of inactivity.
     */
    function showVolumeOverlay() {
        brightnessOverlayActive = false  // Hide brightness if showing
        volumeOverlayActive = true
        volumeHideTimer.restart()
    }
    
    /**
     * Show brightness overlay with auto-hide timer
     * 
     * Called externally (e.g., on brightness key) to display GNOME-style
     * brightness feedback. Auto-hides after 2 seconds of inactivity.
     */
    function showBrightnessOverlay() {
        volumeOverlayActive = false  // Hide volume if showing
        brightnessOverlayActive = true
        brightnessHideTimer.restart()
        Brightness.refresh()  // Refresh brightness value from system
    }
    
    /**
     * Open an expanded screen view
    * @param {string} viewName - One of: "launcher", "live", "toolbar", "power", "clipboard"
     */
    function openView(viewName) {
        // Popup views - toggle independently, close others
        if (viewName === "toolbar" || viewName === "live" || viewName === "launcher") {
            var wasActive = (viewName === "toolbar" && toolbarPopupActive) ||
                            (viewName === "live" && livePopupActive) ||
                            (viewName === "launcher" && appPopupActive)
            // Close all popups first
            toolbarPopupActive = false
            livePopupActive = false
            appPopupActive = false
            // Toggle the requested one
            if (!wasActive) {
                if (viewName === "toolbar") toolbarPopupActive = true
                else if (viewName === "live") livePopupActive = true
                else if (viewName === "launcher") appPopupActive = true
            }
            return
        }
        
        // Close all popups if opening a stacked screen
        toolbarPopupActive = false
        livePopupActive = false
        appPopupActive = false
        
        if (currentView === viewName) return
        if (!screenViews[viewName]) return

        var props = { screenSource: screenViews[viewName] }

        if (currentView === "default") {
            stackViewInternal.push(screenLoaderComponent, props)
        } else {
            stackViewInternal.replace(screenLoaderComponent, props)
        }
        currentView = viewName
    }
    
    /**
     * Close expanded view and return to default collapsed state
     */
    function closeView() {
        // Close all popups
        toolbarPopupActive = false
        livePopupActive = false
        appPopupActive = false
        
        if (currentView === "default") return
        stackViewInternal.pop()
        currentView = "default"
        closeRequested()
    }
    
    /** Whether toolbar popup is active (shows above bar, not inside) */
    property bool toolbarPopupActive: false
    /** Whether live popup is active */
    property bool livePopupActive: false
    /** Whether app launcher popup is active */
    property bool appPopupActive: false
    
    // ═══════════════════════════════════════════════════════════════
    // NOTIFICATION HELPERS - Internal methods for popup widget
    // ═══════════════════════════════════════════════════════════════
    
    /** Current list of popup notifications to display */
    property var currentPopupNotifications: Notifications.popupList
    
    /** Pause auto-dismiss timers (called on hover) */
    function pauseNotificationTimers() { Notifications.pauseAllTimers() }
    
    /** Resume auto-dismiss timers (called on hover exit) */
    function resumeNotificationTimers() { Notifications.resumeAllTimers() }
    
    /** Dismiss a specific notification by ID */
    function dismissPopupNotification(id) { Notifications.discardNotification(id) }

    // System tray menu anchor
    QsMenuAnchor {
        id: trayMenuAnchor
        anchor.window: notchContainer.parentWindow
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top

        onClosed: {
            notchContainer.activeTrayItem = ""
            notchContainer.trayMenuActive = false
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // VOLUME OVERLAY TIMER
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * Timer to auto-hide volume overlay after inactivity
     * Restarts on each volume interaction
     */
    Timer {
        id: volumeHideTimer
        interval: 2000  // 2 seconds
        onTriggered: volumeOverlayActive = false
    }
    
    // ═══════════════════════════════════════════════════════════════
    // BRIGHTNESS OVERLAY TIMER
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * Timer to auto-hide brightness overlay after inactivity
     * Restarts on each brightness interaction
     */
    Timer {
        id: brightnessHideTimer
        interval: 2000  // 2 seconds
        onTriggered: brightnessOverlayActive = false
    }
    
    // ═══════════════════════════════════════════════════════════════
    // TRANSFORM CONTROLLERS - Visual transformations
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * BarTransform - Calculates slide animation and radius
     */
    BarTransform {
        id: barTransform
        target: notchContainer
        discreteMode: notchContainer.discreteMode
        expanded: screenNotchOpen
        showBar: notchContainer.showBar
        contentWidth: 0  // Not used - panel sizes from content
        contentHeight: 0
        animDuration: notchContainer.animDuration
        
        // Radius configuration from Theme
        discreteRadius: 12
        normalRadius: Theme.barRoundness
        expandedRadius: Theme.containerRoundness
    }
    
    /**
     * StackTransitions - Reusable push/pop/replace animations
     */
    StackTransitions {
        id: stackTransitions
        duration: notchContainer.animDuration
    }
    
    // ═══════════════════════════════════════════════════════════════
    // FADE ANIMATORS - Content visibility transitions
    // ═══════════════════════════════════════════════════════════════
    
    /** Fade animator for notification popup visibility */
    FadeAnimator {
        id: notificationFade
        show: notificationPopupActive && !volumeOverlayActive
        duration: notchContainer.animDuration / 2
    }
    
    /** Fade animator for volume overlay visibility */
    FadeAnimator {
        id: volumeFade
        show: volumeOverlayActive && !notificationPopupActive
        duration: notchContainer.animDuration / 2
    }
    
    /** Fade animator for default floating row */
    FadeAnimator {
        id: defaultFade
        show: floatingMode && !volumeOverlayActive && !brightnessOverlayActive && !notificationPopupActive
        duration: notchContainer.animDuration / 2
    }
    
    /** Fade animator for discrete mode row */
    FadeAnimator {
        id: discreteFade
        show: discreteMode && !volumeOverlayActive && !brightnessOverlayActive && !notificationPopupActive
        duration: notchContainer.animDuration / 2
    }
    
    /** Fade animator for brightness overlay visibility */
    FadeAnimator {
        id: brightnessFade
        show: brightnessOverlayActive && !volumeOverlayActive && !notificationPopupActive
        duration: notchContainer.animDuration / 2
    }

    // ═══════════════════════════════════════════════════════════════
    // DIMENSION CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    /** Animation duration from global state (readonly) */
    readonly property int animDuration: Root.State.animDuration
    
    /** Height of minimal discrete notch */
    readonly property int discreteHeight: 24
    
    /** Height of floating bar */
    readonly property int normalHeight: 44
    
    /** Width of volume overlay */
    readonly property int volumeOverlayWidth: 320
    
    /** Height of volume overlay */
    readonly property int volumeOverlayHeight: 44
    
    /** Width of brightness overlay */
    readonly property int brightnessOverlayWidth: 320
    
    /** Height of brightness overlay */
    readonly property int brightnessOverlayHeight: 44
    
    /** Width of notification popup */
    readonly property int notificationPopupWidth: 380
    
    /** Base height of notification popup */
    readonly property int notificationPopupBaseHeight: 70
    
    /** Maximum height of notification popup */
    readonly property int notificationPopupMaxHeight: 400
    
    // ═══════════════════════════════════════════════════════════════
    // ADAPTIVE COLORS - Based on screen content behind bar
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * AdaptiveColors - Provides colors that adapt to background
     * 
     * Samples the screen region behind the bar to provide
     * readable text colors regardless of background.
     */
    AdaptiveColors {
        id: adaptiveColors
        regionId: "notch"
        active: notchContainer.active
        // Sample the screen area where the bar sits (center-bottom)
        sampleX: Math.round((notchContainer.screenWidth - panelBackdrop.width) / 2)
        sampleY: notchContainer.screenHeight - Math.round(panelBackdrop.height) - barMargin
        sampleWidth: Math.round(panelBackdrop.width)
        sampleHeight: Math.round(panelBackdrop.height)
    }

    // ═══════════════════════════════════════════════════════════════
    // PANEL BACKDROP - Pure panel UI container
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * PanelBackdrop - Direct panel content container
     * 
     * Visual container with rounded corners, adaptive background, and blur effect.
     */
    Rectangle {
        id: panelBackdrop
        
        // Content padding - less in discrete mode
        property int contentPadding: discreteMode ? 2 : (screenNotchOpen ? 16 : 12)
        
        // Animated values
        property real _animPadding: contentPadding
        
        Behavior on _animPadding {
            NumberAnimation { duration: animDuration; easing.type: Easing.OutQuart }
        }
        
        // Size from content + padding
        implicitWidth: stackContainer.implicitWidth + _animPadding * 2
        implicitHeight: stackContainer.implicitHeight + _animPadding * 2
        width: implicitWidth
        height: implicitHeight
        
        // Styling - semi-transparent for blur effect
        radius: barTransform.barRadius
        color: adaptiveColors.backgroundIsDark ? 
               Qt.rgba(0, 0, 0, 0.5) : 
               Qt.rgba(1, 1, 1, 0.5)
        border.width: 1
        border.color: adaptiveColors.backgroundIsDark ?
                      Qt.rgba(1, 1, 1, 0.15) :
                      Qt.rgba(0, 0, 0, 0.15)
        
        // Y offset for slide animation
        y: barTransform.slideY
        
        Behavior on color {
            ColorAnimation { duration: 200 }
        }
        
        Behavior on radius {
            NumberAnimation { duration: animDuration; easing.type: Easing.OutQuart }
        }
        
        Behavior on y {
            NumberAnimation { duration: animDuration; easing.type: Easing.OutQuart }
        }
        
        // Content item alias for external access
        property alias contentItem: contentArea
        
        Item {
            id: contentArea
            x: panelBackdrop._animPadding
            y: panelBackdrop._animPadding
            width: parent.width - panelBackdrop._animPadding * 2
            height: parent.height - panelBackdrop._animPadding * 2
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // VISUAL ELEMENTS
    // ═══════════════════════════════════════════════════════════════

    /**
     * Stack Container - Holds the StackView with content
     * Lives inside panelBackdrop's contentItem
     */
    Item {
        id: stackContainer
        parent: panelBackdrop.contentItem
        
        // Size from content - this drives panelBackdrop's size
        implicitWidth: stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitWidth : 100
        implicitHeight: stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitHeight : 36
        width: implicitWidth
        height: implicitHeight

        /**
         * StackView - Screen navigation container
         */
        StackView {
            id: stackViewInternal
            anchors.fill: parent
            clip: true
            initialItem: defaultViewComponent

            // Reusable transition animations
            pushEnter: stackTransitions.pushEnter
            pushExit: stackTransitions.pushExit
            popEnter: stackTransitions.popEnter
            popExit: stackTransitions.popExit
            replaceEnter: stackTransitions.replaceEnter
            replaceExit: stackTransitions.replaceExit
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // DEFAULT VIEW COMPONENT - Collapsed bar content
    // ═══════════════════════════════════════════════════════════════

    /**
     * Default View - Content shown when bar is collapsed
     * 
     * Contains four mutually exclusive content layers:
     * 1. NotificationPopupWidget - When notifications arrive
     * 2. VolumeOverlayWidget - When adjusting volume
     * 3. defaultRow - Unified floating/discrete mode (animates between them)
     * 
     * FadeAnimators control smooth transitions between layers.
     */
    Component {
        id: defaultViewComponent
        Item {
            // Dynamic size based on which content is visible
            implicitWidth: {
                if (notificationPopupActive) return notificationPopupWidth - 32
                if (volumeOverlayActive) return volumeOverlayRow.implicitWidth
                return defaultRow.implicitWidth
            }
            implicitHeight: {
                if (notificationPopupActive) {
                    // Use minimum height to ensure visibility while content loads
                    return Math.max(notificationPopupColumn.implicitHeight, notificationPopupBaseHeight - 24)
                }
                if (volumeOverlayActive) return 36
                return defaultRow.implicitHeight
            }

            /**
             * Notification Popup - Shows incoming notifications
             * 
             * Displays a stack of notification items with app icon,
             * summary, body, time, and dismiss button.
             * Auto-hides after timeout unless hovered.
             */
            NotificationPopupWidget {
                id: notificationPopupColumn
                anchors.fill: parent
                visible: notificationFade.actualVisible
                opacity: notificationFade.animatedOpacity
                
                notifications: currentPopupNotifications
                textColor: adaptiveColors.textColor
                textColorSecondary: adaptiveColors.textColorSecondary
                subtleTextColor: adaptiveColors.subtleTextColor
                animDuration: notchContainer.animDuration
                
                onHoverStarted: pauseNotificationTimers()
                onHoverEnded: resumeNotificationTimers()
                onNotificationClicked: {
                    notchContainer.openView("live")
                    Notifications.hideAllPopups()
                }
                onNotificationDismissed: (id) => dismissPopupNotification(id)
            }

            /**
             * Volume Overlay - GNOME-style volume feedback
             * 
             * Shows volume icon, slider bar, and percentage.
             * Interactive: click/drag slider, scroll to adjust.
             * Auto-hides after 2 seconds of inactivity.
             */
            VolumeOverlayWidget {
                id: volumeOverlayRow
                anchors.centerIn: parent
                visible: volumeFade.actualVisible
                opacity: volumeFade.animatedOpacity
                
                volume: Audio.volume
                muted: Audio.muted
                textColor: adaptiveColors.textColor
                subtleTextColor: adaptiveColors.subtleTextColor
                
                onVolumeChangeRequested: (v) => Audio.setVolume(v)
                onVolumeIncrementRequested: Audio.incrementVolume()
                onVolumeDecrementRequested: Audio.decrementVolume()
                onInteracted: volumeHideTimer.restart()
            }

            /**
             * Brightness Overlay - GNOME-style brightness feedback
             * 
             * Shows brightness icon, slider bar, and percentage.
             * Interactive: click/drag slider, scroll to adjust.
             * Auto-hides after 2 seconds of inactivity.
             */
            BrightnessOverlayWidget {
                id: brightnessOverlayRow
                anchors.centerIn: parent
                visible: brightnessFade.actualVisible
                opacity: brightnessFade.animatedOpacity
                
                brightness: Brightness.brightness
                textColor: adaptiveColors.textColor
                subtleTextColor: adaptiveColors.subtleTextColor
                
                onBrightnessChangeRequested: (v) => Brightness.setBrightness(v)
                onBrightnessIncrementRequested: Brightness.incrementBrightness()
                onBrightnessDecrementRequested: Brightness.decrementBrightness()
                onInteracted: brightnessHideTimer.restart()
            }

            /**
             * Default Row - Unified floating/discrete mode content
             * 
             * All elements animate between modes:
             * - LEFT: Launcher, Overview, Workspaces (fade in normal mode)
             * - CENTER: Time (always), Weather + Notification (animate size/position)
             * - RIGHT: Tray, Status, Power (compact in discrete)
             */
            Item {
                id: defaultRow
                visible: (defaultFade.actualVisible || discreteFade.actualVisible) && !volumeOverlayActive && !brightnessOverlayActive && !notificationPopupActive
                opacity: Math.max(defaultFade.animatedOpacity, discreteFade.animatedOpacity)
                
                // Fill parent width so center anchor works against bar width
                anchors.fill: parent
                
                // Use actual cluster widths - panelBackdrop handles the animation smoothly
                implicitWidth: Math.max(
                    leftCluster.implicitWidth + centerCluster.implicitWidth + rightCluster.implicitWidth + (discreteMode ? 16 : 40),
                    centerCluster.implicitWidth + 2 * Math.max(leftCluster.implicitWidth, rightCluster.implicitWidth) + (discreteMode ? 16 : 40)
                )
                implicitHeight: discreteMode ? 20 : 36

                // Left cluster: launcher, overview, workspaces
                RowLayout {
                    id: leftCluster
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: discreteMode ? 4 : 6

                    // Launcher button (hidden in discrete)
                    Rectangle {
                        Layout.preferredWidth: discreteMode ? 0 : 34
                        Layout.preferredHeight: discreteMode ? 0 : 34
                        radius: Theme.barRoundness / 2
                        color: launcherMouse.containsMouse ? Theme.current.hover : "transparent"
                        opacity: discreteMode ? 0 : 1
                        clip: true
                        
                        Behavior on opacity { NumberAnimation { duration: animDuration / 2 } }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.apps
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: adaptiveColors.iconColor
                        }

                        MouseArea {
                            id: launcherMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notchContainer.openView("launcher")
                            enabled: !discreteMode
                        }
                    }

                    // Overview button (hidden in discrete)
                    Rectangle {
                        Layout.preferredWidth: discreteMode ? 0 : 34
                        Layout.preferredHeight: discreteMode ? 0 : 34
                        radius: 10
                        color: overviewMouse.containsMouse ? Theme.current.hover : "transparent"
                        opacity: discreteMode ? 0 : 1
                        clip: true
                        
                        Behavior on opacity { NumberAnimation { duration: animDuration / 2 } }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.overview
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: adaptiveColors.iconColor
                        }

                        MouseArea {
                            id: overviewMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: State.toggleOverview()
                            enabled: !discreteMode
                        }
                    }

                    // Workspaces widget (always visible)
                    WorkspacesWidget {
                        textColor: adaptiveColors.iconColor
                    }
                }

                // Center cluster: time is the absolute center point of the bar
                // All properties animate based on discreteMode
                Item {
                    id: centerCluster
                    anchors.centerIn: parent
                    
                    // Target size based on mode (for implicitWidth calculation)
                    readonly property real targetWidth: discreteMode 
                        ? timeTextFull.implicitWidth + 8 + 16  // time + margin + small notification
                        : 28 + 10 + timeTextFull.implicitWidth + 10 + 28  // weather + margin + time + margin + notification
                    readonly property real targetHeight: discreteMode ? 20 : 36
                    
                    // Report target size immediately for bar width calculation
                    implicitWidth: targetWidth
                    implicitHeight: targetHeight
                    
                    // Size changes instantly - panelBackdrop animates the container
                    width: targetWidth
                    height: targetHeight

                    /** Time display - CENTER of the bar (always visible) */
                    Text {
                        id: timeTextFull
                        anchors.centerIn: parent
                        color: adaptiveColors.textColor
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        font.family: "monospace"
                        property date now: new Date()
                        text: now.getHours().toString().padStart(2,'0') + ":" + now.getMinutes().toString().padStart(2,'0')
                        Timer {
                            interval: 1000; running: true; repeat: true
                            onTriggered: timeTextFull.now = new Date()
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notchContainer.openView("live")
                        }
                    }

                    /** Weather icon - left of time (only in normal mode) */
                    Item {
                        id: weatherIcon
                        width: 28; height: 28
                        anchors.right: timeTextFull.left
                        anchors.rightMargin: discreteMode ? -width : 10
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: discreteMode ? 0 : 1
                        scale: discreteMode ? 0.5 : 1
                        
                        Behavior on opacity { NumberAnimation { duration: animDuration / 2 } }
                        Behavior on scale { NumberAnimation { duration: animDuration; easing.type: Easing.OutQuart } }
                        
                        Text {
                            anchors.centerIn: parent
                            text: Icons.sun
                            font.family: Icons.font
                            font.pixelSize: 18
                            color: adaptiveColors.iconColor
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notchContainer.openView("live")
                            enabled: !discreteMode
                        }
                    }

                    /** Notification indicator - right of time (animates size/position) */
                    Item {
                        id: notificationIcon
                        width: discreteMode ? 16 : 28
                        height: discreteMode ? 16 : 28
                        anchors.left: timeTextFull.right
                        anchors.leftMargin: discreteMode ? 8 : 10
                        anchors.verticalCenter: parent.verticalCenter
                        
                        /** Notification count badge */
                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: discreteMode ? -1 : 0
                            text: Notifications.list.length > 0 ? Notifications.list.length.toString() : (discreteMode ? "" : "0")
                            color: adaptiveColors.textColor
                            font.pixelSize: discreteMode ? 9 : 11
                            font.weight: Font.DemiBold
                            z: 1
                            visible: discreteMode ? Notifications.list.length > 0 : Notifications.list.length > 0
                            
                            Behavior on font.pixelSize { NumberAnimation { duration: animDuration } }
                        }
                        
                        /** Bell icon */
                        Text {
                            anchors.centerIn: parent
                            text: Notifications.list.length > 0 ? Icons.bellRinging : Icons.bell
                            font.family: Icons.font
                            font.pixelSize: discreteMode ? 13 : 16
                            color: adaptiveColors.iconColor
                            opacity: discreteMode ? (Notifications.list.length > 0 ? 0.7 : 1.0) : (Notifications.list.length === 0 ? 1 : 0)
                            
                            Behavior on font.pixelSize { NumberAnimation { duration: animDuration } }
                            Behavior on opacity { NumberAnimation { duration: animDuration / 2 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notchContainer.openView("live")
                        }
                    }
                    
                    /** Discrete notification icon (overlays, for discrete-only appearance) */
                    Item {
                        id: discreteNotifIcon
                        width: 16; height: 16
                        visible: false  // Only used for size calculation
                    }
                }

                // Right cluster: tray, status, power (animates between modes)
                RowLayout {
                    id: rightCluster
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: discreteMode ? 4 : 8

                    // System tray (hidden in discrete mode)
                    Item {
                        Layout.preferredWidth: discreteMode ? 0 : trayLayout.implicitWidth + 12
                        Layout.preferredHeight: discreteMode ? 0 : 36
                        visible: !discreteMode
                        clip: true

                        // Normal mode tray
                        RowLayout {
                            id: trayLayout
                            anchors.centerIn: parent
                            spacing: 6
                            visible: !discreteMode
                            opacity: discreteMode ? 0 : 1
                            
                            Behavior on opacity { NumberAnimation { duration: animDuration / 2 } }

                            Repeater {
                                model: SystemTray.items
                                delegate: MouseArea {
                                    id: trayItem
                                    required property SystemTrayItem modelData
                                    property string trayId: modelData.id
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.LeftButton) {
                                            modelData.activate()
                                        } else if (mouse.button === Qt.RightButton && modelData.hasMenu && notchContainer.parentWindow) {
                                            notchContainer.activeTrayItem = trayId
                                            notchContainer.trayMenuActive = true
                                            trayMenuAnchor.menu = modelData.menu
                                            var iconPos = trayItem.mapToItem(null, trayItem.width / 2, 0)
                                            trayMenuAnchor.anchor.rect = Qt.rect(iconPos.x, iconPos.y, 1, 1)
                                            trayMenuAnchor.open()
                                        }
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width + 4
                                        height: parent.height + 4
                                        radius: 4
                                        color: adaptiveColors.textColor
                                        visible: notchContainer.activeTrayItem === trayId
                                        opacity: 0.1
                                    }

                                    IconImage {
                                        id: trayIcon
                                        source: trayItem.modelData.icon
                                        anchors.centerIn: parent
                                        implicitWidth: 20
                                        implicitHeight: 20
                                        visible: status === Image.Ready
                                    }
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

                    // Status indicators - clickable for toolbar (hidden in discrete)
                    Item {
                        Layout.preferredWidth: discreteMode ? 0 : statusLayout.implicitWidth + 12
                        Layout.preferredHeight: discreteMode ? 0 : 36
                        opacity: discreteMode ? 0 : 1
                        clip: true
                        
                        Behavior on opacity { NumberAnimation { duration: animDuration / 6 } }
                        
                        // Animate icons up and fade when toolbar is active
                        property real toolbarAnimProgress: toolbarPopupActive ? 1 : 0
                        Behavior on toolbarAnimProgress { NumberAnimation { duration: State.animDuration ?? 300 } }
                        
                        transform: Translate {
                            y: parent.toolbarAnimProgress ? -24 * parent.toolbarAnimProgress : 0
                        }
                        
                        RowLayout {
                            id: statusLayout
                            anchors.centerIn: parent
                            spacing: 6
                            opacity: 1 - parent.toolbarAnimProgress
                            Behavior on opacity { NumberAnimation { duration: animDuration / 4 } }

                            // Volume
                            Item {
                                width: 24; height: 24
                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.volumeIcon(Audio.volume, Audio.muted)
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: adaptiveColors.iconColor
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        Audio.toggleMute()
                                        notchContainer.showVolumeOverlay()
                                    }
                                    onWheel: function(wheel) {
                                        if (wheel.angleDelta.y > 0) Audio.incrementVolume()
                                        else Audio.decrementVolume()
                                        notchContainer.showVolumeOverlay()
                                    }
                                    enabled: parent.parent.opacity > 0.1
                                }
                            }

                            // Network
                            Item {
                                width: 24; height: 24
                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.wifiIcon(Network.networkStrength, Network.wifiEnabled, Network.wifiConnected)
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: adaptiveColors.iconColor
                                }
                            }

                            // Bluetooth
                            Item {
                                width: 24; height: 24
                                visible: Bluetooth.enabled
                                Text {
                                    anchors.centerIn: parent
                                    text: Icons.bluetoothIcon(Bluetooth.enabled, Bluetooth.connected)
                                    font.family: Icons.font
                                    font.pixelSize: 16
                                    color: adaptiveColors.iconColor
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notchContainer.openView("toolbar")
                            enabled: !discreteMode
                        }
                    }
                    
                    // Status icons (discrete mode only - volume, wifi, bluetooth)
                    RowLayout {
                        Layout.preferredWidth: discreteMode ? implicitWidth : 0
                        Layout.preferredHeight: discreteMode ? implicitHeight : 0
                        spacing: 6
                        opacity: discreteMode ? 1 : 0
                        visible: discreteMode
                        
                        // Toolbar animation state
                        property real toolbarAnimProgress: toolbarPopupActive ? 1 : 0
                        Behavior on toolbarAnimProgress { NumberAnimation { duration: State.animDuration ?? 300 } }
                        
                        // Animate icons up and fade
                        transform: Translate { y: parent.toolbarAnimProgress ? -24 * parent.toolbarAnimProgress : 0 }
                        
                        // Volume
                        Text {
                            text: Icons.volumeIcon(Audio.volume, Audio.muted)
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: adaptiveColors.iconColor
                            opacity: 1 - parent.toolbarAnimProgress
                            Behavior on opacity { NumberAnimation { duration: animDuration / 4 } }
                            
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                enabled: discreteMode && !toolbarPopupActive
                                onClicked: {
                                    Audio.toggleMute()
                                    notchContainer.showVolumeOverlay()
                                }
                                onWheel: function(wheel) {
                                    if (wheel.angleDelta.y > 0) Audio.incrementVolume()
                                    else Audio.decrementVolume()
                                    notchContainer.showVolumeOverlay()
                                }
                            }
                        }
                        
                        // WiFi
                        Text {
                            text: Icons.wifiIcon(Network.networkStrength, Network.wifiEnabled, Network.wifiConnected)
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: adaptiveColors.iconColor
                            opacity: 1 - parent.toolbarAnimProgress
                            Behavior on opacity { NumberAnimation { duration: animDuration / 4 } }
                        }
                        
                        // Bluetooth (only if enabled)
                        Text {
                            visible: Bluetooth.enabled
                            text: Icons.bluetoothIcon(Bluetooth.enabled, Bluetooth.connected)
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: adaptiveColors.iconColor
                            opacity: 1 - parent.toolbarAnimProgress
                            Behavior on opacity { NumberAnimation { duration: animDuration / 4 } }
                        }
                    }

                    // Power button (hidden in discrete)
                    Item {
                        Layout.preferredWidth: discreteMode ? 0 : 36
                        Layout.preferredHeight: discreteMode ? 0 : 36
                        opacity: discreteMode ? 0 : 1
                        clip: true
                        
                        Behavior on opacity { NumberAnimation { duration: animDuration / 2 } }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.shutdown
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: powerMouse.containsMouse ? "#ff6b6b" : adaptiveColors.iconColor
                        }

                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notchContainer.openView("power")
                            enabled: !discreteMode
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // SCREEN NAVIGATION
    // ═══════════════════════════════════════════════════════════════

    /** Screen view mapping - Maps view names to QML file paths */
    readonly property var screenViews: ({
        "toolbar": "../../screens/ToolbarScreen.qml",
        "power": "../../screens/PowerScreen.qml",
        "clipboard": "../../screens/ClipboardScreen.qml"
    })

    /**
     * Screen Loader Component - Dynamically loads screen QML files
     * 
     * Connects closeRequested signal from loaded screen to closeView().
     * Focuses loaded item for keyboard input.
     */
    Component {
        id: screenLoaderComponent
        Loader {
            property string screenSource: ""
            source: screenSource
            onLoaded: {
                if (item && item.closeRequested) item.closeRequested.connect(notchContainer.closeView)
                if (item) item.forceActiveFocus()
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // KEYBOARD HANDLING
    // ═══════════════════════════════════════════════════════════════

    /** Close expanded view on Escape key */
    Keys.onEscapePressed: if (isExpanded) closeView()
    
    // ═══════════════════════════════════════════════════════════════
    // HOVER DETECTION
    // ═══════════════════════════════════════════════════════════════

    /**
     * BarHoverDetector - Detects mouse hover directly over the bar
     * 
     * Sets _barHover which combines with externalHover for _realHover.
     * Also emits barHoverChanged signal for backwards compatibility.
     */
    BarHoverDetector {
        onHoverChanged: (hovering) => {
            notchContainer._barHover = hovering
            notchContainer.barHoverChanged(hovering)
        }
    }
}
