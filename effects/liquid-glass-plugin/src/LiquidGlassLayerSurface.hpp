#pragma once

/*
 * Liquid Glass Effect for Layer Surfaces (Panels/Bars)
 * 
 * This extends the liquid glass effect to work with wlr-layer-shell
 * surfaces like status bars, docks, and overlays.
 */

#include "globals.hpp"

#include <hyprland/src/desktop/LayerSurface.hpp>
#include <hyprland/src/render/OpenGL.hpp>
#include <string>
#include <unordered_set>

class CLiquidGlassLayerEffect {
  public:
    // Check if a layer surface should have the liquid glass effect
    static bool shouldApplyEffect(PHLLS layerSurface);
    
    // Sample the background before the layer renders
    static void sampleBackground(PHLLS layerSurface, CBox box);
    
    // Apply the liquid glass effect to a layer surface
    static void applyEffect(PHLLS layerSurface, CBox box, float alpha);
    
    // Register a namespace pattern for liquid glass effect
    static void addNamespacePattern(const std::string& pattern);
    static void removeNamespacePattern(const std::string& pattern);
    static void clearNamespacePatterns();
    
    // Get the sample framebuffer for a layer surface
    static CFramebuffer& getOrCreateSampleFB(PHLLS layerSurface);
    
  private:
    // Namespace patterns that should get liquid glass effect
    static inline std::unordered_set<std::string> s_namespacePatterns;
    
    // Per-surface framebuffers for background sampling
    static inline std::unordered_map<PHLLS, CFramebuffer> s_sampleFramebuffers;
    
    // Check if namespace matches any pattern
    static bool matchesPattern(const std::string& ns);
};
