import QtQuick
import "../../globals"
import "../effects"

/**
 * BubbleContainer - Central hover manager for bubble items.
 *
 * ONE MouseArea handles all hover detection via hit-testing.
 * Items register their bounds; the container decides who is focused.
 *
 * Each item is in one of three states:
 *   "normal"    – nothing focused
 *   "focused"   – this item is hovered
 *   "unfocused" – another item is hovered
 */
Item {
    id: container

    // Animation / layout
    property bool show: false
    property int animDuration: 300
    property real originX: width
    property real originY: height

    // Screen position for adaptive colors
    property int screenX: 0
    property int screenY: 0

    // ── Centralized focus state ────────────────────────────────────
    property string focusedItemId: ""

    // Clear focus when popup hides
    onShowChanged: {
        if (!show) {
            focusedItemId = ""
            _blockZone = null
        }
    }

    // ── Item registry ──────────────────────────────────────────────
    // Items call register/unregister with their center-based coords
    property var _items: ({})   // itemId → { cx, cy, w, h }

    // When a transform item is focused, its expanded bounds act as a
    // "block zone" — any base items overlapping it are excluded from
    // hit-testing so they can't steal focus.
    property var _blockZone: null  // null or { cx, cy, w, h }

    function registerItem(itemId, cx, cy, w, h) {
        _items[itemId] = { cx: cx, cy: cy, w: w, h: h }
    }

    function unregisterItem(itemId) {
        delete _items[itemId]
    }

    // Called by TransformBubble when it gains focus — blocks items underneath
    function setBlockZone(cx, cy, w, h) {
        _blockZone = { cx: cx, cy: cy, w: w, h: h }
    }

    // Called by TransformBubble when it loses focus
    function clearBlockZone() {
        _blockZone = null
    }

    // ── Single hover MouseArea ─────────────────────────────────────
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: container.show
        acceptedButtons: Qt.NoButton
        z: 99999  // Above everything so it always gets hover
        visible: container.show  // Don't block hover for other popups when hidden

        onPositionChanged: (mouse) => updateHover(mouse.x, mouse.y)
        onEntered: (mouse) => updateHover(mouseX, mouseY)
        onExited: container.focusedItemId = ""
    }

    function _hitTest(mx, my, cx, cy, w, h) {
        var left = cx - w / 2
        var top  = cy - h / 2
        return mx >= left && mx <= left + w && my >= top && my <= top + h
    }

    // Check if two rectangles (center-based) overlap
    function _rectsOverlap(aCx, aCy, aW, aH, bCx, bCy, bW, bH) {
        return Math.abs(aCx - bCx) < (aW + bW) / 2 &&
               Math.abs(aCy - bCy) < (aH + bH) / 2
    }

    function updateHover(mx, my) {
        var current = focusedItemId

        // If a block zone is active (transform bubble is expanded),
        // check if the mouse is inside it — if so, keep current focus
        if (_blockZone && current !== "") {
            if (_hitTest(mx, my, _blockZone.cx, _blockZone.cy, _blockZone.w, _blockZone.h)) {
                return  // mouse is inside the expanded area, stay locked
            }
        }

        // Find which item the mouse is over, skipping items blocked
        // by the expanded transform bubble
        var hitId = ""
        var hitDist = Infinity
        for (var id in _items) {
            // Skip the currently focused transform item (it's already focused)
            if (id === current && _blockZone) continue

            var item = _items[id]

            // Skip items whose base bounds overlap with the block zone
            if (_blockZone && _rectsOverlap(
                    item.cx, item.cy, item.w, item.h,
                    _blockZone.cx, _blockZone.cy, _blockZone.w, _blockZone.h)) {
                continue
            }

            if (_hitTest(mx, my, item.cx, item.cy, item.w, item.h)) {
                var dx = mx - item.cx
                var dy = my - item.cy
                var dist = dx * dx + dy * dy
                if (dist < hitDist) {
                    hitDist = dist
                    hitId = id
                }
            }
        }

        if (hitId !== "") {
            // Mouse hit an item OUTSIDE the block zone → switch focus
            focusedItemId = hitId
        } else if (current !== "") {
            // Mouse in empty space, keep current focus
        } else {
            focusedItemId = ""
        }
    }

    // ── Shared adaptive colors ─────────────────────────────────────
    AdaptiveColors {
        id: adaptiveColors
        regionId: "bubbleContainer"
        active: container.show && container.width > 0
        sampleX: container.screenX
        sampleY: container.screenY
        sampleWidth: Math.round(container.width)
        sampleHeight: Math.round(container.height)
    }

    readonly property bool isDark: adaptiveColors.backgroundIsDark
    readonly property color textColor: adaptiveColors.textColor
    readonly property color subtleColor: adaptiveColors.subtleTextColor
    readonly property color iconColor: adaptiveColors.iconColor
}
