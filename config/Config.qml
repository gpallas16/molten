pragma Singleton
import QtQuick

/**
 * Config - Global configuration for Molten shell
 * 
 * Bar modes:
 * - "floating": Always visible with full UI
 * - "discrete": Always shows compact UI, hides on hover
 * - "hidden": Hidden until edge hit, then shows as floating
 * - "dynamic": No windows = floating, active windows = discrete behavior
 */
QtObject {
    // ═══════════════════════════════════════════════════════════════
    // BAR MODES
    // ═══════════════════════════════════════════════════════════════
    
    /** Workspace bar (left) - launcher, overview, workspaces */
    readonly property string workspaceBarMode: "discrete"
    
    /** Main bar (center) - dynamic island notch */
    readonly property string mainBarMode: "discrete"
    
    /** Status bar (right) - tray, status, power */
    readonly property string statusBarMode: "discrete"
}
