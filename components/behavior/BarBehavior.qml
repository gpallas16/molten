import QtQuick

/**
 * BarBehavior - Reusable bar behavior controller
 * 
 * MODES:
 * - floating: Bar always visible, full UI
 * - discrete: Bar compact by default, hover → floating, leave → discrete
 * - hidden: Bar hidden by default, edge hit → shows temporarily
 * - dynamic: No windows = floating, has windows = discrete behavior
 */
Item {
    id: root
    visible: false
    width: 0
    height: 0
    
    // ═══════════════════════════════════════════════════════════════
    // INPUTS
    // ═══════════════════════════════════════════════════════════════
    
    property string mode: "dynamic"
    property string debugName: "unknown"
    property bool barHovered: false
    property bool zoneHovered: false
    property bool edgeHit: false
    property bool popupActive: false
    property bool isExpanded: false
    property bool hasActiveWindows: false
    property int hideDelay: 1000
    
    // ═══════════════════════════════════════════════════════════════
    // OUTPUTS
    // ═══════════════════════════════════════════════════════════════
    
    property string internalState: "floating"
    readonly property bool barVisible: internalState !== "hidden"
    readonly property bool isCompact: {
        if (isExpanded || popupActive) return false
        if (mode === "floating") return false
        return internalState === "discrete"
    }
    
    // ═══════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════
    
    function getRestState() {
        if (mode === "floating") return "floating"
        if (mode === "discrete") return "discrete"
        if (mode === "hidden") return "hidden"
        // dynamic: discrete when windows, floating when no windows
        return hasActiveWindows ? "discrete" : "floating"
    }
    
    function isDiscreteActive() {
        return mode === "discrete" || (mode === "dynamic" && hasActiveWindows)
    }
    
    // ═══════════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════════
    
    Component.onCompleted: {
        internalState = getRestState()
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MODE CHANGES
    // ═══════════════════════════════════════════════════════════════
    
    onModeChanged: {
        internalState = getRestState()
    }
    
    // ═══════════════════════════════════════════════════════════════
    // DISCRETE MODE: Hover bar → floating, leave → discrete
    // Uses debounce timers to prevent rapid toggling at edges
    // ═══════════════════════════════════════════════════════════════
    
    Timer {
        id: hoverExpandTimer
        interval: 80  // Short delay before expanding
        onTriggered: {
            if (root.barHovered && root.internalState === "discrete") {
                root.internalState = "floating"
            }
        }
    }
    
    Timer {
        id: hoverCollapseTimer
        interval: 150  // Slightly longer delay before collapsing
        onTriggered: {
            if (!root.barHovered && root.internalState === "floating" && root.isDiscreteActive()) {
                root.internalState = "discrete"
            }
        }
    }
    
    onBarHoveredChanged: {
        if (isExpanded || popupActive) return
        
        if (isDiscreteActive()) {
            if (barHovered) {
                // Cancel any pending collapse, start expand timer
                hoverCollapseTimer.stop()
                if (internalState === "discrete") {
                    hoverExpandTimer.restart()
                }
            } else {
                // Cancel any pending expand, start collapse timer
                hoverExpandTimer.stop()
                if (internalState === "floating") {
                    hoverCollapseTimer.restart()
                }
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // HIDDEN MODE: Edge hit shows bar temporarily
    // ═══════════════════════════════════════════════════════════════
    
    onEdgeHitChanged: {
        if (mode !== "hidden") return
        if (isExpanded || popupActive) return
        
        if (edgeHit && internalState === "hidden") {
            internalState = "floating"
        }
    }
    
    onZoneHoveredChanged: {
        if (mode !== "hidden") return
        if (isExpanded || popupActive) return
        
        // Left zone → hide again
        if (!zoneHovered && internalState === "floating") {
            internalState = "hidden"
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // DYNAMIC MODE: Window changes
    // ═══════════════════════════════════════════════════════════════
    
    onHasActiveWindowsChanged: {
        if (mode !== "dynamic") return
        if (isExpanded || popupActive) return
        
        // Only change if not currently hovered
        if (!barHovered) {
            internalState = hasActiveWindows ? "discrete" : "floating"
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // POPUP/EXPAND: Force floating while active
    // ═══════════════════════════════════════════════════════════════
    
    onPopupActiveChanged: {
        if (popupActive) {
            internalState = "floating"
        } else if (!barHovered) {
            internalState = getRestState()
        }
    }
    
    onIsExpandedChanged: {
        if (isExpanded) {
            internalState = "floating"
        } else if (!barHovered) {
            internalState = getRestState()
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PUBLIC: Temporarily show bar (expand to floating temporarily)
    // ═══════════════════════════════════════════════════════════════
    
    function showTemporarily() {
        if (mode === "floating") return  // Already always floating
        
        internalState = "floating"
        tempTimer.restart()
    }
    
    Timer {
        id: tempTimer
        interval: root.hideDelay
        onTriggered: {
            if (!root.popupActive && !root.isExpanded && !root.barHovered && !root.zoneHovered && !root.edgeHit) {
                root.internalState = root.getRestState()
            }
        }
    }
}
