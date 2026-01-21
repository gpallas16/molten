import QtQuick

/**
 * BarTransform - Reusable bar transformation controller
 * 
 * Provides dimension calculations, animations, and slide transforms for bars.
 * Use this to add consistent discrete mode sizing and show/hide animations.
 * 
 * Usage:
 *   BarTransform {
 *       id: barTransform
 *       target: myBar
 *       discreteMode: barBehavior.uiState === "discrete"
 *       showBar: barBehavior.barVisible
 *       expanded: isExpanded
 *       contentWidth: contentItem.implicitWidth
 *       contentHeight: contentItem.implicitHeight
 *   }
 *   
 *   MyBar {
 *       id: myBar
 *       implicitWidth: barTransform.barWidth
 *       implicitHeight: barTransform.barHeight
 *       transform: barTransform.slideTransform
 *   }
 */
Item {
    id: root
    visible: false
    width: 0
    height: 0
    
    // ═══════════════════════════════════════════════════════════════
    // CONFIGURATION INPUTS
    // ═══════════════════════════════════════════════════════════════
    
    // Target item to apply transforms to (for slide animation reference)
    property Item target: null
    
    // Whether in discrete (minimal) mode
    property bool discreteMode: false
    
    // Whether bar is expanded (showing content views)
    property bool expanded: false
    
    // Whether to show the bar (for slide animation)
    property bool showBar: true
    
    // Content dimensions (from the bar's internal content)
    property real contentWidth: 0
    property real contentHeight: 0
    
    // Animation duration (default from State.animDuration if available)
    property int animDuration: 300
    
    // ═══════════════════════════════════════════════════════════════
    // DISCRETE MODE DIMENSIONS
    // ═══════════════════════════════════════════════════════════════
    
    property int discreteWidth: 110
    property int discreteHeight: 24
    property int normalHeight: 44
    property int expandedPadding: 32
    property int collapsedPadding: 24
    property int minExpandedWidth: 290
    property int minExpandedHeight: 44
    
    // ═══════════════════════════════════════════════════════════════
    // RADIUS CONFIGURATION
    // ═══════════════════════════════════════════════════════════════
    
    property real discreteRadius: 12
    property real normalRadius: 22      // Theme.barRoundness default
    property real expandedRadius: 16    // Theme.containerRoundness default
    
    // Whether to use flat bottom in discrete mode (attached to screen edge)
    property bool flatBottomInDiscrete: true
    
    // ═══════════════════════════════════════════════════════════════
    // SLIDE ANIMATION CONFIGURATION
    // ═══════════════════════════════════════════════════════════════
    
    property int slideDuration: 400
    property real slideOvershoot: 1.2
    property int slideEasingIn: Easing.InQuad
    property int slideEasingOut: Easing.OutBack
    property real slideOffset: 20  // Extra offset when hidden
    
    // ═══════════════════════════════════════════════════════════════
    // OUTPUT PROPERTIES
    // ═══════════════════════════════════════════════════════════════
    
    // Calculated width for the bar
    readonly property real barWidth: {
        if (discreteMode && !expanded) {
            return discreteWidth
        } else if (expanded) {
            return Math.max(contentWidth + expandedPadding, minExpandedWidth)
        } else {
            return contentWidth + collapsedPadding
        }
    }
    
    // Calculated height for the bar
    readonly property real barHeight: {
        if (discreteMode && !expanded) {
            return discreteHeight
        } else if (expanded) {
            return Math.max(contentHeight + expandedPadding, minExpandedHeight)
        } else {
            return normalHeight
        }
    }
    
    // Calculated radius for the bar
    readonly property real barRadius: {
        if (discreteMode && !expanded) {
            return discreteRadius
        } else if (expanded) {
            return expandedRadius
        } else {
            return normalRadius
        }
    }
    
    // Whether to use flat bottom (for discrete mode attached to edge)
    readonly property bool flatBottom: discreteMode && !expanded && flatBottomInDiscrete
    
    // Current Y offset for slide animation
    readonly property real slideY: internal.slideY
    
    // The slide transform to apply to the target
    readonly property Translate slideTransform: slideTranslate
    
    // ═══════════════════════════════════════════════════════════════
    // INTERNAL STATE
    // ═══════════════════════════════════════════════════════════════
    
    QtObject {
        id: internal
        property real slideY: root.showBar ? 0 : (root.target ? root.target.implicitHeight + root.slideOffset : 64 + root.slideOffset)
        
        Behavior on slideY {
            NumberAnimation {
                duration: root.slideDuration
                easing.type: root.showBar ? root.slideEasingOut : root.slideEasingIn
                easing.overshoot: root.slideOvershoot
            }
        }
    }
    
    Translate {
        id: slideTranslate
        y: internal.slideY
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ANIMATED VALUES (for smooth transitions)
    // ═══════════════════════════════════════════════════════════════
    
    // These provide animated versions of the output values
    // Use these if you want the bar to animate its own properties
    
    property real animatedWidth: barWidth
    property real animatedHeight: barHeight
    property real animatedRadius: barRadius
    
    Behavior on animatedWidth {
        enabled: animDuration > 0
        NumberAnimation {
            duration: root.animDuration
            easing.type: root.expanded ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: root.expanded ? 1.8 : 1.0
        }
    }
    
    Behavior on animatedHeight {
        enabled: animDuration > 0
        NumberAnimation {
            duration: root.animDuration
            easing.type: root.expanded ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: root.expanded ? 1.8 : 1.0
        }
    }
    
    Behavior on animatedRadius {
        enabled: animDuration > 0
        NumberAnimation {
            duration: root.animDuration
            easing.type: root.expanded ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: root.expanded ? 1.8 : 1.0
        }
    }
}
