import QtQuick

/**
 * SizeAnimator - Reusable animated size behaviors
 * 
 * Provides configurable size animations with different easing modes.
 * Attach to an item and use the animated properties for smooth transitions.
 * 
 * Usage:
 *   SizeAnimator {
 *       id: sizeAnim
 *       targetWidth: myCalculatedWidth
 *       targetHeight: myCalculatedHeight
 *       expanded: isExpanded
 *   }
 *   
 *   Item {
 *       implicitWidth: sizeAnim.width
 *       implicitHeight: sizeAnim.height
 *   }
 */
Item {
    id: root
    visible: false
    width: 0
    height: 0
    
    // ═══════════════════════════════════════════════════════════════
    // INPUTS
    // ═══════════════════════════════════════════════════════════════
    
    // Target dimensions to animate to
    property real targetWidth: 0
    property real targetHeight: 0
    property real targetRadius: 0
    
    // State that affects easing behavior
    property bool expanded: false
    
    // Animation configuration
    property int duration: 300
    property bool enabled: duration > 0
    
    // Easing configuration
    property int normalEasing: Easing.OutQuart
    property int expandedEasing: Easing.OutBack
    property real normalOvershoot: 1.0
    property real expandedOvershoot: 1.8
    
    // ═══════════════════════════════════════════════════════════════
    // OUTPUTS - Animated values
    // ═══════════════════════════════════════════════════════════════
    
    readonly property alias animatedWidth: internal.animWidth
    readonly property alias animatedHeight: internal.animHeight
    readonly property alias animatedRadius: internal.animRadius
    
    // Convenience aliases
    readonly property real w: internal.animWidth
    readonly property real h: internal.animHeight
    readonly property real r: internal.animRadius
    
    // ═══════════════════════════════════════════════════════════════
    // INTERNAL
    // ═══════════════════════════════════════════════════════════════
    
    QtObject {
        id: internal
        
        property real animWidth: root.targetWidth
        property real animHeight: root.targetHeight
        property real animRadius: root.targetRadius
        
        Behavior on animWidth {
            enabled: root.enabled
            NumberAnimation {
                duration: root.duration
                easing.type: root.expanded ? root.expandedEasing : root.normalEasing
                easing.overshoot: root.expanded ? root.expandedOvershoot : root.normalOvershoot
            }
        }
        
        Behavior on animHeight {
            enabled: root.enabled
            NumberAnimation {
                duration: root.duration
                easing.type: root.expanded ? root.expandedEasing : root.normalEasing
                easing.overshoot: root.expanded ? root.expandedOvershoot : root.normalOvershoot
            }
        }
        
        Behavior on animRadius {
            enabled: root.enabled
            NumberAnimation {
                duration: root.duration
                easing.type: root.expanded ? root.expandedEasing : root.normalEasing
                easing.overshoot: root.expanded ? root.expandedOvershoot : root.normalOvershoot
            }
        }
    }
}
