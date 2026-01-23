import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../globals" as Root
import "../../globals"
import "../../services"
import "../../services/notification_utils.js" as NotificationUtils
import "../effects"
import "../behavior"
import "../transforms"
import "../widgets"

/**
 * MainBar - Dynamic Island style notch bar (presentational component)
 * 
 * A macOS Dynamic Island inspired notification bar that expands and contracts
 * based on content and user interaction. This component is purely presentational -
 * all behavior logic (visibility, mode switching) should be controlled by parent
 * using BarBehavior.
 * 
 * Features:
 * - Two display modes: floating (full UI) and compact (minimal notch)
 * - Expandable screens: launcher, notifications, weather, toolbar, power
 * - Volume overlay with GNOME-style feedback
 * - Notification popup with auto-dismiss
 * - Smooth animations using reusable transform components
 * 
 * @example
 *   MainBar {
 *       compactMode: barBehavior.isCompact  // Compact UI toggle
 *       showBar: barBehavior.barVisible     // Controls slide animation
 *       onBarHoverChanged: (h) => barBehavior.barHovered = h
 *       onPopupActiveChanged: (a) => // handle popup state
 *   }
 * 
 * @see BarBehavior - For behavior/state machine logic
 * @see BarTransform - For dimension and slide calculations
 * @see SizeAnimator - For animated size transitions
 */
Item {
    id: notchContainer

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

    // Internal hover tracking
    property bool _realHover: false
    
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
        popupActive: notchContainer.notificationPopupActive || notchContainer.volumeOverlayActive || notchContainer.brightnessOverlayActive
        isExpanded: notchContainer.isExpanded
        hasActiveWindows: notchContainer.hasActiveWindows
        hideDelay: 1000
    }
    
    // Computed from behavior
    readonly property bool compactMode: behavior.isCompact
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
    onNotificationPopupActiveChanged: popupActiveChanged(notificationPopupActive || volumeOverlayActive || brightnessOverlayActive)
    onVolumeOverlayActiveChanged: popupActiveChanged(notificationPopupActive || volumeOverlayActive || brightnessOverlayActive)
    onBrightnessOverlayActiveChanged: popupActiveChanged(notificationPopupActive || volumeOverlayActive || brightnessOverlayActive)
    
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
     * @param {string} viewName - One of: "launcher", "live", "notifications", "toolbar", "power", "clipboard"
     */
    function openView(viewName) {
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
        if (currentView === "default") return
        stackViewInternal.pop()
        currentView = "default"
        closeRequested()
    }
    
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
     * BarTransform - Calculates dimensions and slide animation
     * 
     * Handles:
     * - Bar width/height based on discrete/floating/expanded state
     * - Corner radius transitions
     * - Slide Y offset for show/hide animation
     */
    BarTransform {
        id: barTransform
        target: notchContainer
        discreteMode: notchContainer.discreteMode
        expanded: screenNotchOpen
        showBar: notchContainer.showBar
        contentWidth: stackContainer.width
        contentHeight: stackContainer.height
        animDuration: notchContainer.animDuration
        
        // Dimension configuration
        discreteWidth: notchContainer.discreteWidth
        discreteHeight: notchContainer.discreteHeight
        normalHeight: notchContainer.normalHeight
        expandedPadding: 32
        collapsedPadding: 24
        
        // Radius configuration from Theme
        discreteRadius: 12
        normalRadius: Theme.barRoundness
        expandedRadius: Theme.containerRoundness
    }
    
    /**
     * SizeAnimator - Provides smooth animated dimensions
     * 
     * Wraps the target dimensions with animation behaviors.
     * Handles special cases: notification popup, volume and brightness overlay
     * override normal dimensions.
     */
    SizeAnimator {
        id: sizeAnimator
        duration: notchContainer.animDuration
        expanded: screenNotchOpen
        
        // Width: popup > volume > brightness > normal transform
        targetWidth: {
            if (notificationPopupActive && currentView === "default") {
                return notificationPopupWidth
            } else if (volumeOverlayActive && currentView === "default") {
                return volumeOverlayWidth
            } else if (brightnessOverlayActive && currentView === "default") {
                return brightnessOverlayWidth
            } else {
                return barTransform.barWidth
            }
        }
        
        // Height: popup (dynamic) > volume > brightness > normal transform
        targetHeight: {
            if (notificationPopupActive && currentView === "default") {
                var contentHeight = stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitHeight : 0
                // Use base height as minimum to ensure notification is visible
                return Math.max(contentHeight + 24, notificationPopupBaseHeight)
            } else if (volumeOverlayActive && currentView === "default") {
                return volumeOverlayHeight
            } else if (brightnessOverlayActive && currentView === "default") {
                return brightnessOverlayHeight
            } else {
                return barTransform.barHeight
            }
        }
        
        targetRadius: barTransform.barRadius
    }
    
    /**
     * StackTransitions - Reusable push/pop/replace animations
     * 
     * Provides consistent transition animations for the StackView
     * when navigating between screens.
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
    
    /** Apply slide transform from BarTransform */
    transform: barTransform.slideTransform

    // ═══════════════════════════════════════════════════════════════
    // DIMENSION CONSTANTS
    // ═══════════════════════════════════════════════════════════════
    
    /** Animation duration from global state (readonly) */
    readonly property int animDuration: Root.State.animDuration
    
    /** Width of minimal discrete notch */
    readonly property int discreteWidth: 110
    
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
    // ADAPTIVE COLORS - Based on wallpaper/background
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * AdaptiveColors - Provides colors that adapt to background
     * 
     * Samples the wallpaper in the "notch" region to provide
     * readable text colors regardless of background.
     */
    AdaptiveColors {
        id: adaptiveColors
        region: "notch"
        active: notchContainer.active
    }
    
    // ═══════════════════════════════════════════════════════════════
    // EMBEDDED GLASS BACKDROP - Auto-syncs with bar dimensions
    // ═══════════════════════════════════════════════════════════════
    EmbeddedGlassBackdrop {
        backdropName: "notch"
        horizontalAlign: "center"
        margin: notchContainer.compactMode ? 0 : 6
        // Use explicit dimensions since MainBar uses SizeAnimator for animated sizes
        explicitWidth: sizeAnimator.animatedWidth
        explicitHeight: sizeAnimator.animatedHeight
        targetRadius: {
            if (notchContainer.discreteMode && !notchContainer.screenNotchOpen) {
                return 12  // Discrete notch roundness
            } else if (notchContainer.screenNotchOpen) {
                return Theme.containerRoundness
            } else {
                return Theme.barRoundness
            }
        }
        flatBottom: notchContainer.discreteMode && !notchContainer.screenNotchOpen
        yOffset: barTransform.slideY
        backdropVisible: notchContainer.active
        startupDelay: 150
    }
    
    // ═══════════════════════════════════════════════════════════════
    // SIZE BINDING - Final dimensions with animation trigger hack
    // ═══════════════════════════════════════════════════════════════
    
    /**
     * Animation trigger hack - forces binding re-evaluation
     * Random value added (multiplied by 0) to force recalculation
     */
    property real animationTrigger: 0
    onScreenNotchOpenChanged: {
        if (screenNotchOpen) {
            animationTrigger = Math.random()
        }
    }

    /** Final animated width from SizeAnimator */
    implicitWidth: sizeAnimator.animatedWidth + (screenNotchOpen ? animationTrigger * 0 : 0)
    
    /** Final animated height from SizeAnimator */
    implicitHeight: sizeAnimator.animatedHeight + (screenNotchOpen ? animationTrigger * 0 : 0)
    
    // Explicit size for BarHoverDetector (anchors.fill requires explicit size)
    width: sizeAnimator.animatedWidth
    height: sizeAnimator.animatedHeight

    // ═══════════════════════════════════════════════════════════════
    // VISUAL ELEMENTS
    // ═══════════════════════════════════════════════════════════════

    /**
     * ShadowBorder - Background with shadow and rounded corners
     * 
     * Provides the glass-like background with configurable radius
     * and optional flat bottom for discrete mode (attached to edge).
     */
    ShadowBorder {
        radius: sizeAnimator.animatedRadius
        flatBottom: barTransform.flatBottom && !volumeOverlayActive && !notificationPopupActive
    }

    /**
     * Stack Container - Holds the StackView with content
     * 
     * Provides padding around the StackView content.
     * Width/height expand when showing screens.
     */
    Item {
        id: stackContainer
        anchors.centerIn: parent
        width: stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitWidth + (screenNotchOpen ? 32 : 0) : (screenNotchOpen ? 32 : 0)
        height: stackViewInternal.currentItem ? stackViewInternal.currentItem.implicitHeight + (screenNotchOpen ? 32 : 0) : (screenNotchOpen ? 32 : 0)
        clip: true

        /**
         * StackView - Screen navigation container
         * 
         * Manages push/pop/replace transitions between:
         * - Default view (collapsed bar content)
         * - Screen views (launcher, notifications, etc.)
         */
        StackView {
            id: stackViewInternal
            anchors.fill: parent
            anchors.margins: screenNotchOpen ? 16 : 0
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
     * 3. defaultRow - Floating mode (weather, time, notification count)
     * 4. discreteRow - Discrete mode (time, notification icon)
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
                if (discreteMode) return discreteRow.implicitWidth
                return defaultRow.implicitWidth
            }
            implicitHeight: {
                if (notificationPopupActive) {
                    // Use minimum height to ensure visibility while content loads
                    return Math.max(notificationPopupColumn.implicitHeight, notificationPopupBaseHeight - 24)
                }
                if (volumeOverlayActive) return 36
                if (discreteMode) return 20
                return 36
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
                    notchContainer.openView("notifications")
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
             * Default Row - Floating mode content
             * 
             * Shows: Weather icon | Time | Notification bell
             * Each element is clickable to open its respective screen.
             */
            RowLayout {
                id: defaultRow
                anchors.centerIn: parent
                spacing: 10
                visible: defaultFade.actualVisible
                opacity: defaultFade.animatedOpacity

                /** Weather icon - opens live screen */
                Item {
                    width: 28; height: 28
                    Text {
                        anchors.centerIn: parent
                        text: "🌤"; font.pixelSize: 18
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notchContainer.openView("live")
                    }
                }

                /** Separator dot */
                Rectangle { width: 4; height: 4; radius: 2; color: adaptiveColors.subtleTextColor }

                /** Time display - opens live screen */
                Text {
                    id: timeTextFull
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

                /** Separator dot */
                Rectangle { width: 4; height: 4; radius: 2; color: adaptiveColors.subtleTextColor }

                /** Notification indicator - opens notifications screen */
                Item {
                    width: 28; height: 28
                    
                    /** Notification count badge */
                    Text {
                        anchors.centerIn: parent
                        text: Notifications.list.length > 0 ? Notifications.list.length.toString() : "0"
                        color: adaptiveColors.textColor
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        z: 1
                        visible: Notifications.list.length > 0
                    }
                    
                    /** Bell icon (shown when no notifications) */
                    Text {
                        anchors.centerIn: parent
                        text: "🔔"; font.pixelSize: 16
                        visible: Notifications.list.length === 0
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notchContainer.openView("notifications")
                    }
                }
            }
            
            /**
             * Discrete Row - Minimal notch content
             * 
             * Shows: Time | Notification icon/count
             * More compact than floating mode, docks to screen edge.
             */
            Row {
                id: discreteRow
                anchors.centerIn: parent
                 spacing: 10
                visible: discreteFade.actualVisible
                opacity: discreteFade.animatedOpacity

                /** Time display (monospace) */
                Text {
                    id: timeTextDiscrete
                    anchors.verticalCenter: parent.verticalCenter
                    color: adaptiveColors.textColor
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.family: "monospace"
                    property date now: new Date()
                    text: now.getHours().toString().padStart(2,'0') + ":" + now.getMinutes().toString().padStart(2,'0')
                    Timer {
                        interval: 1000; running: true; repeat: true
                        onTriggered: timeTextDiscrete.now = new Date()
                    }
                }

                /** Notification icon with count */
                Item {
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    
                    /** Count badge */
                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        text: Notifications.list.length > 0 
                              ? Notifications.list.length.toString() 
                              : ""
                        color: adaptiveColors.textColor
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        z: 1
                    }
                    
                    /** Bell icon */
                    Text {
                        anchors.centerIn: parent
                        text: "🔔"
                        font.pixelSize: 13
                        opacity: Notifications.list.length > 0 ? 0.7 : 1.0
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
        "launcher": "../../screens/AppLauncher.qml",
        "live": "../../screens/LiveScreen.qml",
        "notifications": "../../screens/NotificationScreen.qml",
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
     * BarHoverDetector - Detects mouse hover over the bar
     * 
     * Sets _realHover for internal BarBehavior.
     * Also emits barHoverChanged signal for backwards compatibility.
     */
    BarHoverDetector {
        onHoverChanged: (hovering) => {
            notchContainer._realHover = hovering
            notchContainer.barHoverChanged(hovering)
        }
    }
}
