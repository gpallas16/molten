import QtQuick

/**
 * StackTransitions - Reusable StackView transition configurations
 * 
 * Provides pre-configured transitions for StackView push/pop/replace operations.
 * Use these to get consistent animations across all stacked views.
 * 
 * Usage:
 *   StackTransitions {
 *       id: transitions
 *       duration: 300
 *   }
 *   
 *   StackView {
 *       pushEnter: transitions.pushEnter
 *       pushExit: transitions.pushExit
 *       popEnter: transitions.popEnter
 *       popExit: transitions.popExit
 *       replaceEnter: transitions.replaceEnter
 *       replaceExit: transitions.replaceExit
 *   }
 */
Item {
    id: root
    visible: false
    width: 0
    height: 0
    
    // ═══════════════════════════════════════════════════════════════
    // CONFIGURATION
    // ═══════════════════════════════════════════════════════════════
    
    property int duration: 300
    
    // Push animation config
    property real pushEnterScaleFrom: 0.8
    property real pushExitScaleTo: 1.05
    property int pushEnterEasing: Easing.OutBack
    property real pushEnterOvershoot: 1.2
    
    // Pop animation config  
    property real popEnterScaleFrom: 1.05
    property real popExitScaleTo: 0.95
    
    // Replace animation config (same as push by default)
    property real replaceEnterScaleFrom: 0.8
    property real replaceExitScaleTo: 1.05
    
    // Opacity easing (shared)
    property int opacityEasing: Easing.OutQuart
    property int scaleEasing: Easing.OutQuart
    
    // ═══════════════════════════════════════════════════════════════
    // TRANSITIONS
    // ═══════════════════════════════════════════════════════════════
    
    readonly property Transition pushEnter: Transition {
        PropertyAnimation { 
            property: "opacity"
            from: 0; to: 1
            duration: root.duration
            easing.type: root.opacityEasing
        }
        PropertyAnimation { 
            property: "scale"
            from: root.pushEnterScaleFrom; to: 1
            duration: root.duration
            easing.type: root.pushEnterEasing
            easing.overshoot: root.pushEnterOvershoot
        }
    }
    
    readonly property Transition pushExit: Transition {
        PropertyAnimation { 
            property: "opacity"
            from: 1; to: 0
            duration: root.duration
            easing.type: root.opacityEasing
        }
        PropertyAnimation { 
            property: "scale"
            from: 1; to: root.pushExitScaleTo
            duration: root.duration
            easing.type: root.scaleEasing
        }
    }
    
    readonly property Transition popEnter: Transition {
        PropertyAnimation { 
            property: "opacity"
            from: 0; to: 1
            duration: root.duration
            easing.type: root.opacityEasing
        }
        PropertyAnimation { 
            property: "scale"
            from: root.popEnterScaleFrom; to: 1
            duration: root.duration
            easing.type: root.scaleEasing
        }
    }
    
    readonly property Transition popExit: Transition {
        PropertyAnimation { 
            property: "opacity"
            from: 1; to: 0
            duration: root.duration
            easing.type: root.opacityEasing
        }
        PropertyAnimation { 
            property: "scale"
            from: 1; to: root.popExitScaleTo
            duration: root.duration
            easing.type: root.scaleEasing
        }
    }
    
    readonly property Transition replaceEnter: Transition {
        PropertyAnimation { 
            property: "opacity"
            from: 0; to: 1
            duration: root.duration
            easing.type: root.opacityEasing
        }
        PropertyAnimation { 
            property: "scale"
            from: root.replaceEnterScaleFrom; to: 1
            duration: root.duration
            easing.type: root.pushEnterEasing
            easing.overshoot: root.pushEnterOvershoot
        }
    }
    
    readonly property Transition replaceExit: Transition {
        PropertyAnimation { 
            property: "opacity"
            from: 1; to: 0
            duration: root.duration
            easing.type: root.opacityEasing
        }
        PropertyAnimation { 
            property: "scale"
            from: 1; to: root.replaceExitScaleTo
            duration: root.duration
            easing.type: root.scaleEasing
        }
    }
}
