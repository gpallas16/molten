import QtQuick

/**
 * FadeAnimator - Reusable opacity/visibility animations
 * 
 * Provides configurable fade animations for showing/hiding elements.
 * Can be used for cross-fading between states.
 * 
 * Usage:
 *   FadeAnimator {
 *       id: fadeAnim
 *       visible: someCondition
 *       duration: 200
 *   }
 *   
 *   Item {
 *       opacity: fadeAnim.opacity
 *       visible: fadeAnim.actualVisible
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
    
    // Whether the element should be visible
    property bool show: true
    
    // Animation configuration
    property int duration: 200
    property int fadeInDuration: duration
    property int fadeOutDuration: duration
    property int easing: Easing.InOutQuad
    property int fadeInEasing: easing
    property int fadeOutEasing: easing
    
    // Optional scale animation during fade
    property bool animateScale: false
    property real scaleFrom: 0.95
    property real scaleTo: 1.0
    
    // ═══════════════════════════════════════════════════════════════
    // OUTPUTS
    // ═══════════════════════════════════════════════════════════════
    
    // Current animated opacity (renamed to avoid FINAL property conflict)
    readonly property alias animatedOpacity: internal.opacity
    
    // Current animated scale (if animateScale is true)
    readonly property alias animatedScale: internal.scale
    
    // Whether the element should actually be visible (stays true during fade out)
    readonly property bool actualVisible: internal.opacity > 0 || show
    
    // ═══════════════════════════════════════════════════════════════
    // INTERNAL
    // ═══════════════════════════════════════════════════════════════
    
    QtObject {
        id: internal
        
        property real opacity: root.show ? 1.0 : 0.0
        property real scale: root.show ? root.scaleTo : root.scaleFrom
        
        Behavior on opacity {
            NumberAnimation {
                duration: root.show ? root.fadeInDuration : root.fadeOutDuration
                easing.type: root.show ? root.fadeInEasing : root.fadeOutEasing
            }
        }
        
        Behavior on scale {
            enabled: root.animateScale
            NumberAnimation {
                duration: root.show ? root.fadeInDuration : root.fadeOutDuration
                easing.type: root.show ? root.fadeInEasing : root.fadeOutEasing
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    // Create fade animation properties for use in Transitions
    function createFadeIn(targetDuration) {
        return {
            property: "opacity",
            from: 0,
            to: 1,
            duration: targetDuration || fadeInDuration,
            easing: fadeInEasing
        }
    }
    
    function createFadeOut(targetDuration) {
        return {
            property: "opacity",
            from: 1,
            to: 0,
            duration: targetDuration || fadeOutDuration,
            easing: fadeOutEasing
        }
    }
}
