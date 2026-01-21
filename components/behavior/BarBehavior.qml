import QtQuick

/**
 * BarBehavior - Reusable bar behavior controller
 * 
 * Provides visibility and UI state management for bars with 4 behavior modes:
 * 
 * - floating: Bar always visible with floating UI
 * - discrete: Bar shows compact UI, hides on hover, returns on hover leave
 * - hidden: Bar hidden until edge hit or hover, then shows as floating
 * - dynamic: No active windows = floating UI, active windows = discrete behavior
 * 
 * State machine (for dynamic mode with active windows):
 *   floating ──[timer expires]──> discrete
 *   discrete ──[hover]──────────> hidden (bar slides away)
 *   hidden ───[hover leaves]────> discrete (bar returns)
 *   hidden ───[edge hit]────────> floating
 *   any ──────[no windows]──────> floating
 */
Item {
    id: root
    visible: false  // This is a non-visual item
    width: 0
    height: 0
    
    // ═══════════════════════════════════════════════════════════════
    // CONFIGURATION INPUTS
    // ═══════════════════════════════════════════════════════════════
    
    property string mode: "dynamic"
    property bool barHovered: false
    property bool edgeHit: false
    property bool popupActive: false
    property bool isExpanded: false
    property bool hasActiveWindows: false
    property int hideDelay: 1000
    
    // ═══════════════════════════════════════════════════════════════
    // OUTPUT PROPERTIES
    // ═══════════════════════════════════════════════════════════════
    
    // The internal state: "floating", "discrete", "hidden"
    property string internalState: "floating"
    
    // Initialize state based on mode at startup
    Component.onCompleted: {
        if (mode === "hidden" && hasActiveWindows) {
            internalState = "hidden"
        } else if (mode === "discrete") {
            internalState = "discrete"
        } else {
            internalState = "floating"
        }
    }
    
    // Whether the bar should be visible (hidden state = not visible)
    readonly property bool barVisible: internalState !== "hidden"
    
    /**
     * Whether the bar should show compact UI.
     * Each bar interprets "compact" visually however it wants:
     * - MainBar: shrinks height to minimal notch
     * - WorkspaceBar: hides launcher/overview buttons, shows only workspaces
     * - StatusBar: hides status/power, shows only tray icons
     * 
     * Compact = true when: in discrete state (or hidden, for consistency)
     * Compact = false when: in floating state
     */
    readonly property bool isCompact: {
        if (isExpanded || popupActive) return false
        if (mode === "floating") return false
        // All other modes: compact depends on internalState
        return internalState === "discrete" || internalState === "hidden"
    }
    
    // When entering floating state with active windows, start timer to return to discrete
    onInternalStateChanged: {
        if (internalState === "floating" && hasActiveWindows && !barHovered && !popupActive && !isExpanded && !edgeHit) {
            discreteTimer.restart()
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STATE MACHINE
    // ═══════════════════════════════════════════════════════════════
    
    // Helper: get the "rest" state for current mode (state to return to when not interacting)
    function getRestState() {
        if (mode === "floating") return "floating"
        // hidden mode: show floating on empty workspace, hidden when windows active
        if (mode === "hidden") return hasActiveWindows ? "hidden" : "floating"
        if (mode === "discrete") return "discrete"
        // dynamic: depends on active windows
        return hasActiveWindows ? "discrete" : "floating"
    }
    
    // Timer to return from floating to rest state
    Timer {
        id: discreteTimer
        interval: root.hideDelay
        onTriggered: {
            root._temporarilyShown = false
            if (!root.popupActive && !root.isExpanded && !root.barHovered && !root.edgeHit) {
                var restState = root.getRestState()
                if (root.internalState === "floating" && restState !== "floating") {
                    root.internalState = restState
                }
            }
        }
    }
    
    // Track if showTemporarily was called (to avoid immediate hide on workspace switch)
    property bool _temporarilyShown: false
    
    // React to hasActiveWindows changes (matters for dynamic and hidden modes)
    onHasActiveWindowsChanged: {
        if (mode === "floating" || mode === "discrete") return
        
        if (!hasActiveWindows) {
            // No windows - go to floating
            discreteTimer.stop()
            _temporarilyShown = false
            if (internalState === "discrete" || internalState === "hidden") {
                internalState = "floating"
            }
        } else {
            // Has windows - go to rest state unless temporarily shown or hovered
            var restState = getRestState()
            if (internalState === "floating" && !barHovered && !popupActive && !isExpanded && !edgeHit) {
                if (_temporarilyShown) {
                    discreteTimer.restart()
                } else {
                    internalState = restState
                }
            }
        }
    }
    
    // React to bar hover changes - THIS IS THE CORE BEHAVIOR
    onBarHoveredChanged: {
        if (barHovered) {
            discreteTimer.stop()
            
            // Discrete + hover → Hidden (bar slides away to let user work)
            if (internalState === "discrete") {
                internalState = "hidden"
            }
            // Floating + hover → stay floating (user is interacting with bar)
            
        } else {
            // Hover ended
            var restState = getRestState()
            
            // Hidden + hover leaves → return to rest state
            if (internalState === "hidden") {
                if (!popupActive && !isExpanded) {
                    internalState = restState
                } else {
                    internalState = "floating"
                }
            }
            // Floating + hover leaves → start timer to return to rest state
            else if (internalState === "floating" && restState !== "floating" && !popupActive && !isExpanded && !edgeHit) {
                discreteTimer.restart()
            }
        }
    }
    
    // Edge hit brings bar back as floating (and keeps it there while edge is hit)
    onEdgeHitChanged: {
        if (edgeHit) {
            discreteTimer.stop()
            if (internalState === "discrete" || internalState === "hidden") {
                internalState = "floating"
            }
        } else {
            // Edge left - start hide timer to return to rest state
            var restState = getRestState()
            if (internalState === "floating" && restState !== "floating" && !barHovered && !popupActive && !isExpanded) {
                discreteTimer.restart()
            }
        }
    }
    
    // Popup active - switch to floating and stay there
    onPopupActiveChanged: {
        if (popupActive) {
            internalState = "floating"
            discreteTimer.stop()
        } else {
            var restState = getRestState()
            if (restState !== "floating" && !barHovered && !edgeHit) {
                discreteTimer.restart()
            }
        }
    }
    
    // Expanded - switch to floating
    onIsExpandedChanged: {
        if (isExpanded) {
            discreteTimer.stop()
        } else {
            var restState = getRestState()
            if (restState !== "floating" && !barHovered && !popupActive && !edgeHit) {
                discreteTimer.restart()
            }
        }
    }
    
    /**
     * Temporarily show the bar (brings to floating, then auto-hides after hideDelay)
     * Use this for events like workspace changes
     */
    function showTemporarily() {
        discreteTimer.stop()
        _temporarilyShown = true
        internalState = "floating"
        var restState = getRestState()
        if (restState !== "floating") {
            discreteTimer.restart()
        }
    }
}
