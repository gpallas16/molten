import QtQuick
import Quickshell
import Quickshell.Wayland
import "../config"

/**
 * Wallpaper - Native wallpaper rendering using Wayland layer-shell
 * 
 * Renders the wallpaper as a background layer surface, no external tools needed.
 * Supports fade transitions between wallpapers.
 */
PanelWindow {
    id: wallpaper

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell:wallpaper"
    exclusionMode: ExclusionMode.Ignore

    color: "#000000"

    // Current wallpaper path from config
    property string wallpaperPath: Config.activeWallpaper
    
    // Track the previous wallpaper for crossfade
    property string previousWallpaper: ""
    
    // Animation duration
    property int transitionDuration: 500

    onWallpaperPathChanged: {
        if (wallpaperPath && wallpaperPath !== previousWallpaper) {
            // Start crossfade transition
            if (previousWallpaper) {
                backImage.source = "file://" + previousWallpaper
                backImage.opacity = 1
                frontImage.opacity = 0
                frontImage.source = "file://" + wallpaperPath
                fadeIn.start()
            } else {
                // First load - no transition
                frontImage.source = "file://" + wallpaperPath
                frontImage.opacity = 1
            }
            previousWallpaper = wallpaperPath
        }
    }

    // Back image (old wallpaper during transition)
    Image {
        id: backImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        cache: false
    }

    // Front image (new wallpaper)
    Image {
        id: frontImage
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        cache: false
        opacity: 0
        
        onStatusChanged: {
            if (status === Image.Ready && opacity === 0 && wallpaperPath) {
                // Image loaded, start fade if not already running
                if (!fadeIn.running) {
                    fadeIn.start()
                }
            }
        }
    }

    // Fade in animation
    NumberAnimation {
        id: fadeIn
        target: frontImage
        property: "opacity"
        from: 0
        to: 1
        duration: wallpaper.transitionDuration
        easing.type: Easing.OutCubic
        
        onFinished: {
            // Clear back image after transition
            backImage.source = ""
            backImage.opacity = 0
        }
    }

    // Initial load
    Component.onCompleted: {
        if (wallpaperPath) {
            frontImage.source = "file://" + wallpaperPath
            frontImage.opacity = 1
            previousWallpaper = wallpaperPath
        }
    }
}
