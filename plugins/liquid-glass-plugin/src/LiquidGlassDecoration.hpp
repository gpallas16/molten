#pragma once

/*
 * Liquid Glass Window Decoration
 * Applies the liquid glass effect to individual windows
 */

#include <hyprland/src/render/decorations/IHyprWindowDecoration.hpp>
#include <hyprland/src/render/Framebuffer.hpp>
#include <string>

class CLiquidGlassDecoration : public IHyprWindowDecoration {
  public:
    CLiquidGlassDecoration(PHLWINDOW pWindow);
    virtual ~CLiquidGlassDecoration() = default;

    // IHyprWindowDecoration interface
    virtual SDecorationPositioningInfo getPositioningInfo();
    virtual void                       onPositioningReply(const SDecorationPositioningReply& reply);
    virtual void                       draw(PHLMONITOR, float const& a);
    virtual eDecorationType            getDecorationType();
    virtual void                       updateWindow(PHLWINDOW);
    virtual void                       damageEntire();
    virtual eDecorationLayer           getDecorationLayer();
    virtual uint64_t                   getDecorationFlags();
    virtual std::string                getDisplayName();

    // Public accessors
    PHLWINDOW                          getOwner();
    void                               renderPass(PHLMONITOR pMonitor, const float& a);

    // Weak pointer to self for tracking
    WP<CLiquidGlassDecoration>         m_self;

  private:
    PHLWINDOWREF m_pWindow;
    CFramebuffer m_sampleFB;
    CFramebuffer m_workFB;
    
    // Luminance tracking
    float        m_lastLuminance = 0.5f;
    int          m_luminanceUpdateCounter = 0;

    // Sample the background behind the window
    void sampleBackground(CFramebuffer& sourceFB, CBox box);
    
    // Calculate and report background luminance
    float calculateLuminance(CBox& box);
    void  reportLuminance(const std::string& windowTitle, float luminance);
    
    // Apply the liquid glass shader
    void applyLiquidGlassEffect(CFramebuffer& sourceFB, CFramebuffer& targetFB,
                                 CBox& rawBox, CBox& transformedBox, float windowAlpha);

    friend class CLiquidGlassPassElement;
};
