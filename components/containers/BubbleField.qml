import QtQuick
import "../effects"

/**
 * BubbleField - Container that manages bubble collision and pushing
 * 
 * All bubbles register themselves here and the field calculates
 * collision offsets for each bubble based on expanded items.
 */
Item {
    id: field
    
    // Shared adaptive colors for all bubbles
    AdaptiveColors {
        id: adaptiveColors
        regionId: "toolbar"
        sampleX: Math.round(field.mapToGlobal(0, 0).x)
        sampleY: Math.round(field.mapToGlobal(0, 0).y)
        sampleWidth: Math.round(field.width)
        sampleHeight: Math.round(field.height)
        active: field.visible && field.width > 0
    }
    
    // Expose adaptive colors
    readonly property bool isDark: adaptiveColors.backgroundIsDark
    readonly property color textColor: adaptiveColors.textColor
    readonly property color subtleColor: adaptiveColors.subtleTextColor
    readonly property color iconColor: adaptiveColors.iconColor
    
    // All registered bubbles
    property var bubbles: []
    
    // Register a bubble
    function registerBubble(bubble) {
        bubbles.push(bubble)
        bubblesChanged()
    }
    
    // Unregister a bubble
    function unregisterBubble(bubble) {
        var idx = bubbles.indexOf(bubble)
        if (idx >= 0) {
            bubbles.splice(idx, 1)
            bubblesChanged()
        }
    }
    
    // Calculate push offset for a bubble based on all expanded bubbles
    function calculatePushOffset(bubble) {
        var offsetX = 0
        var offsetY = 0
        var pushDistance = 40
        
        for (var i = 0; i < bubbles.length; i++) {
            var other = bubbles[i]
            if (other === bubble || !other.expanded) continue
            
            // Get actual positions
            var bx = bubble.x + bubble.width / 2
            var by = bubble.y + bubble.height / 2
            var ox = other.x + other.width / 2
            var oy = other.y + other.height / 2
            
            // Check overlap
            var dx = bx - ox
            var dy = by - oy
            var distance = Math.sqrt(dx * dx + dy * dy)
            var minDist = (bubble.width + other.width) / 2 + 10
            
            if (distance < minDist && distance > 0) {
                // Normalize and push
                var pushX = (dx / distance) * pushDistance
                var pushY = (dy / distance) * pushDistance
                offsetX += pushX
                offsetY += pushY
            }
        }
        
        return { x: offsetX, y: offsetY }
    }
}
