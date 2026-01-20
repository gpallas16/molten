pragma Singleton
import QtQuick

QtObject {
    id: root

    // Theme mode: "light" or "dark"
    property string mode: "light"

    // Toggle between themes
    function toggle() {
        mode = mode === "dark" ? "light" : "dark"
    }

    // Roundness values
    readonly property int barRoundness: 22
    readonly property int containerRoundness: 56

    // ═══════════════════════════════════════════════════════════════
    // LIGHT THEME
    // ═══════════════════════════════════════════════════════════════
    readonly property QtObject light: QtObject {
        // Glass overlay colors (light with transparency) - Apple style, ultra transparent
        readonly property color glassBase: Qt.rgba(1, 1, 1, 0.04)
        readonly property color glassBorder: Qt.rgba(1, 1, 1, 0)      // No border for cleaner look
        readonly property color glassBorderInner: Qt.rgba(1, 1, 1, 0) // No inner border
        
        // 3D effect: gradients simulate depth and lighting - enhanced for more depth
        readonly property color gradientTop: Qt.rgba(1, 1, 1, 0.35)      // Bright highlight at top
        readonly property color gradientMiddle: Qt.rgba(1, 1, 1, 0.02)   // Very transparent middle
        readonly property color gradientBottom: Qt.rgba(0.8, 0.8, 0.8, 0.25) // Stronger shadow at bottom
        
        // Expanded state - slightly more visible
        readonly property color glassExpanded: Qt.rgba(0.98, 0.98, 0.98, 0.15)
        
        // 3D depth: shadow colors - enhanced for more depth
        readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.18)
        readonly property color highlightColor: Qt.rgba(1, 1, 1, 0.5)
        
        // Text and icons (black)
        readonly property color text: Qt.rgba(0, 0, 0, 0.9)
        readonly property color textSecondary: Qt.rgba(0, 0, 0, 0.6)
        readonly property color icon: Qt.rgba(0, 0, 0, 0.8)
        
        // Interactive states
        readonly property color hover: Qt.rgba(0, 0, 0, 0.08)
        readonly property color active: Qt.rgba(0, 0, 0, 0.12)
    }

    // ═══════════════════════════════════════════════════════════════
    // DARK THEME
    // ═══════════════════════════════════════════════════════════════
    readonly property QtObject dark: QtObject {
        // Glass overlay colors (dark with transparency) - Apple style
        readonly property color glassBase: Qt.rgba(0.15, 0.15, 0.15, 0.4)
        readonly property color glassBorder: Qt.rgba(1, 1, 1, 0)       // No border for cleaner look
        readonly property color glassBorderInner: Qt.rgba(1, 1, 1, 0)  // No inner border
        
        // 3D effect: gradients simulate depth and lighting
        readonly property color gradientTop: Qt.rgba(1, 1, 1, 0.2)       // Bright highlight at top
        readonly property color gradientMiddle: Qt.rgba(1, 1, 1, 0.05)   // Transparent middle
        readonly property color gradientBottom: Qt.rgba(0, 0, 0, 0.15)   // Shadow at bottom
        
        // Expanded state
        readonly property color glassExpanded: Qt.rgba(0.15, 0.15, 0.15, 0.5)
        
        // Text and icons (white)
        readonly property color text: Qt.rgba(1, 1, 1, 0.9)
        readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.6)
        readonly property color icon: Qt.rgba(1, 1, 1, 0.8)
        
        // Interactive states
        readonly property color hover: Qt.rgba(1, 1, 1, 0.12)
        readonly property color active: Qt.rgba(1, 1, 1, 0.18)
        
        // 3D depth: shadow colors
        readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.25)
        readonly property color highlightColor: Qt.rgba(1, 1, 1, 0.2)
    }

    // ═══════════════════════════════════════════════════════════════
    // CURRENT THEME (dynamic)
    // ═══════════════════════════════════════════════════════════════
    readonly property QtObject current: mode === "light" ? light : dark
}
