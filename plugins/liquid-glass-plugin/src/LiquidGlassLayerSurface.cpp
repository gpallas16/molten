#include "LiquidGlassLayerSurface.hpp"
#include "globals.hpp"

#include <GLES3/gl32.h>
#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprutils/string/String.hpp>
#include <chrono>
#include <regex>
#include <fstream>

using namespace Hyprutils::String;

// Forward declaration
extern void logToFile(const std::string& msg);

// ============================================================================
// PATTERN MATCHING
// ============================================================================

bool CLiquidGlassLayerEffect::matchesPattern(const std::string& ns) {
    for (const auto& pattern : s_namespacePatterns) {
        // Support simple wildcard matching
        if (pattern == ns)
            return true;
        
        // Check if pattern is a prefix match (e.g., "molten-*")
        if (pattern.back() == '*') {
            std::string prefix = pattern.substr(0, pattern.length() - 1);
            if (ns.substr(0, prefix.length()) == prefix)
                return true;
        }
        
        // Check if pattern is a suffix match (e.g., "*-bar")
        if (pattern.front() == '*') {
            std::string suffix = pattern.substr(1);
            if (ns.length() >= suffix.length() && 
                ns.substr(ns.length() - suffix.length()) == suffix)
                return true;
        }
    }
    return false;
}

bool CLiquidGlassLayerEffect::shouldApplyEffect(PHLLS layerSurface) {
    if (!layerSurface)
        return false;
    
    // Check if effect is enabled globally
    static auto* const PENABLED = (Hyprlang::INT* const*)HyprlandAPI::getConfigValue(
        PHANDLE, "plugin:liquid-glass:enabled")->getDataStaticPtr();
    if (!**PENABLED)
        return false;
    
    // Check if this namespace should get the effect
    return matchesPattern(layerSurface->m_namespace);
}

// ============================================================================
// NAMESPACE MANAGEMENT
// ============================================================================

void CLiquidGlassLayerEffect::addNamespacePattern(const std::string& pattern) {
    s_namespacePatterns.insert(pattern);
}

void CLiquidGlassLayerEffect::removeNamespacePattern(const std::string& pattern) {
    s_namespacePatterns.erase(pattern);
}

void CLiquidGlassLayerEffect::clearNamespacePatterns() {
    s_namespacePatterns.clear();
    s_sampleFramebuffers.clear();
}

// ============================================================================
// FRAMEBUFFER MANAGEMENT
// ============================================================================

CFramebuffer& CLiquidGlassLayerEffect::getOrCreateSampleFB(PHLLS layerSurface) {
    auto& fb = s_sampleFramebuffers[layerSurface];
    return fb;
}

// ============================================================================
// BACKGROUND SAMPLING (called BEFORE layer renders)
// ============================================================================

void CLiquidGlassLayerEffect::sampleBackground(PHLLS layerSurface, CBox box) {
    if (!layerSurface || !g_pGlobalState)
        return;
    
    auto& sampleFB = getOrCreateSampleFB(layerSurface);
    
    // Get the current framebuffer (contains everything rendered so far, without this layer)
    auto* currentFB = g_pHyprOpenGL->m_renderData.currentFB;
    if (!currentFB || !currentFB->isAllocated())
        return;
    
    // Ensure valid box dimensions
    if (box.width <= 0 || box.height <= 0)
        return;
        
    int fbWidth = static_cast<int>(box.width);
    int fbHeight = static_cast<int>(box.height);
    
    // Allocate sample framebuffer if needed
    if (!sampleFB.isAllocated() || sampleFB.m_size.x != fbWidth || sampleFB.m_size.y != fbHeight) {
        sampleFB.alloc(fbWidth, fbHeight, currentFB->m_drmFormat);
        if (!sampleFB.isAllocated())
            return;
    }
    
    // Sample coordinates
    int x0 = std::max(0, static_cast<int>(box.x));
    int x1 = static_cast<int>(box.x + box.width);
    int y0 = std::max(0, static_cast<int>(box.y));
    int y1 = static_cast<int>(box.y + box.height);
    
    // Save current GL state
    GLint prevFB;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prevFB);
    
    // Blit the background region to our sample framebuffer
    glBindFramebuffer(GL_READ_FRAMEBUFFER, currentFB->getFBID());
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, sampleFB.getFBID());
    glBlitFramebuffer(x0, y0, x1, y1, 0, 0, fbWidth, fbHeight, GL_COLOR_BUFFER_BIT, GL_LINEAR);
    
    // Restore framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, prevFB);
}

// ============================================================================
// EFFECT APPLICATION (called AFTER layer renders)
// ============================================================================

void CLiquidGlassLayerEffect::applyEffect(PHLLS layerSurface, CBox box, float alpha) {
    if (!layerSurface || !g_pGlobalState)
        return;
    
    // Get config values
    static auto* const PBLUR       = (Hyprlang::FLOAT* const*)HyprlandAPI::getConfigValue(PHANDLE, "plugin:liquid-glass:blur_strength")->getDataStaticPtr();
    static auto* const PREFRACT    = (Hyprlang::FLOAT* const*)HyprlandAPI::getConfigValue(PHANDLE, "plugin:liquid-glass:refraction_strength")->getDataStaticPtr();
    static auto* const PCHROMATIC  = (Hyprlang::FLOAT* const*)HyprlandAPI::getConfigValue(PHANDLE, "plugin:liquid-glass:chromatic_aberration")->getDataStaticPtr();
    static auto* const PFRESNEL    = (Hyprlang::FLOAT* const*)HyprlandAPI::getConfigValue(PHANDLE, "plugin:liquid-glass:fresnel_strength")->getDataStaticPtr();
    static auto* const PSPECULAR   = (Hyprlang::FLOAT* const*)HyprlandAPI::getConfigValue(PHANDLE, "plugin:liquid-glass:specular_strength")->getDataStaticPtr();
    static auto* const POPACITY    = (Hyprlang::FLOAT* const*)HyprlandAPI::getConfigValue(PHANDLE, "plugin:liquid-glass:glass_opacity")->getDataStaticPtr();
    static auto* const PEDGE       = (Hyprlang::FLOAT* const*)HyprlandAPI::getConfigValue(PHANDLE, "plugin:liquid-glass:edge_thickness")->getDataStaticPtr();

    auto& sampleFB = getOrCreateSampleFB(layerSurface);
    
    static int logCount = 0;
    if (logCount < 5) {
        logToFile("applyEffect: sampleFB allocated=" + std::to_string(sampleFB.isAllocated()) + 
                  " size=" + std::to_string(sampleFB.m_size.x) + "x" + std::to_string(sampleFB.m_size.y) +
                  " box=" + std::to_string(box.width) + "x" + std::to_string(box.height) +
                  " alpha=" + std::to_string(alpha) +
                  " opacity=" + std::to_string(static_cast<float>(**POPACITY)));
        logCount++;
    }
    
    // Check that we have a valid sampled background
    if (!sampleFB.isAllocated())
        return;
    
    // Get the current framebuffer
    auto* currentFB = g_pHyprOpenGL->m_renderData.currentFB;
    if (!currentFB || !currentFB->isAllocated())
        return;
    
    // Ensure valid box dimensions
    if (box.width <= 0 || box.height <= 0)
        return;
    
    // Simple test: render the sampled texture with Hyprland's renderTexture
    auto tex = sampleFB.getTexture();
    if (!tex)
        return;
        
    // Render the sampled background texture - use 1.0 opacity for debugging
    CHyprOpenGLImpl::STextureRenderData renderData;
    renderData.a = 1.0f;  // Force full opacity for debugging
    g_pHyprOpenGL->renderTexture(tex, box, renderData);
}
