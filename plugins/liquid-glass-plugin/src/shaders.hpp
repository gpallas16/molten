// Auto-generated shader header - Do not edit!
#pragma once

#include <unordered_map>
#include <string>

inline const std::unordered_map<std::string, const char*> SHADERS = {
    {"liquidglass.frag", R"GLSL(
#version 300 es
precision highp float;

/*
 * Apple-style Liquid Glass Fragment Shader
 * 
 * Implements the key visual elements of Apple's iOS 26 Liquid Glass design:
 * 1. Edge refraction with displacement mapping
 * 2. Chromatic aberration (RGB channel separation)
 * 3. Fresnel effect (edge glow based on viewing angle)
 * 4. Specular highlights (sharp light reflections)
 * 5. Subtle interior blur for glass thickness
 */

// Uniforms
uniform sampler2D tex;
uniform vec2 topLeft;
uniform vec2 fullSize;
uniform vec2 fullSizeUntransformed;
uniform float radius;
uniform float time;

// Configurable parameters
uniform float blurStrength;        // Interior blur amount (0.0 - 2.0)
uniform float refractionStrength;  // Edge refraction intensity (0.0 - 0.15)
uniform float chromaticAberration; // RGB separation amount (0.0 - 0.02)
uniform float fresnelStrength;     // Edge glow intensity (0.0 - 1.0)
uniform float specularStrength;    // Highlight brightness (0.0 - 1.0)
uniform float glassOpacity;        // Overall glass opacity (0.0 - 1.0)
uniform float edgeThickness;       // How thick the refractive edge is (0.0 - 0.3)

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

// Constants
const float PI = 3.14159265359;
const float AA_EDGE = 0.002; // Anti-aliasing edge softness

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

// Compute signed distance to rounded rectangle (in UV space)
float roundedBoxSDF(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Get alpha mask for rounded corners
float getRoundedAlpha(vec2 uv) {
    vec2 center = vec2(0.5);
    vec2 pos = uv - center;
    
    // Convert radius from pixels to UV space, accounting for aspect ratio
    float aspectRatio = fullSize.x / fullSize.y;
    vec2 scaledPos = pos * vec2(aspectRatio, 1.0);
    
    // Half size in UV space
    vec2 halfSize = vec2(0.5 * aspectRatio, 0.5);
    
    // Radius in UV space (approximate)
    float uvRadius = radius / fullSize.y;
    
    float dist = roundedBoxSDF(scaledPos, halfSize, uvRadius);
    
    // Smooth edge for anti-aliasing
    return 1.0 - smoothstep(-AA_EDGE, AA_EDGE, dist);
}

// Smooth edge mask with configurable falloff
float getEdgeMask(vec2 uv, float thickness) {
    vec2 center = vec2(0.5);
    vec2 pos = uv - center;
    
    // Account for aspect ratio
    float aspectRatio = fullSize.x / fullSize.y;
    vec2 scaledPos = pos * vec2(aspectRatio, 1.0);
    vec2 halfSize = vec2(0.5 * aspectRatio, 0.5);
    
    // Radius in UV space
    float uvRadius = radius / fullSize.y;
    
    // Compute distance from inner edge
    float innerThickness = thickness * min(aspectRatio, 1.0);
    float dist = roundedBoxSDF(scaledPos, halfSize - innerThickness, max(uvRadius - innerThickness, 0.0));
    
    // Create smooth gradient from edge to center
    float edgeFactor = smoothstep(-thickness * 0.5, thickness * 0.5, dist);
    return clamp(edgeFactor, 0.0, 1.0);
}

// Get signed distance from edge (negative = inside, positive = outside)
float getEdgeDistance(vec2 uv) {
    vec2 center = vec2(0.5);
    vec2 pos = uv - center;
    
    float aspectRatio = fullSize.x / fullSize.y;
    vec2 scaledPos = pos * vec2(aspectRatio, 1.0);
    vec2 halfSize = vec2(0.5 * aspectRatio, 0.5);
    float uvRadius = radius / fullSize.y;
    
    return roundedBoxSDF(scaledPos, halfSize, uvRadius);
}

// Get the direction pointing toward the nearest edge (normalized)
vec2 getEdgeNormal(vec2 uv) {
    vec2 center = vec2(0.5);
    vec2 pos = uv - center;
    
    float aspectRatio = fullSize.x / fullSize.y;
    vec2 scaledPos = pos * vec2(aspectRatio, 1.0);
    vec2 halfSize = vec2(0.5 * aspectRatio, 0.5);
    float uvRadius = radius / fullSize.y;
    
    // Compute gradient of SDF for normal direction
    float eps = 0.001;
    float d = roundedBoxSDF(scaledPos, halfSize, uvRadius);
    float dx = roundedBoxSDF(scaledPos + vec2(eps, 0.0), halfSize, uvRadius) - d;
    float dy = roundedBoxSDF(scaledPos + vec2(0.0, eps), halfSize, uvRadius) - d;
    
    vec2 normal = normalize(vec2(dx, dy) + 0.0001);
    // Convert back from aspect-corrected space
    normal.x /= aspectRatio;
    return normalize(normal);
}

// Generate refraction displacement based on edge proximity
vec2 getRefractionOffset(vec2 uv, float edgeMask) {
    vec2 center = vec2(0.5);
    vec2 fromCenter = uv - center;
    float dist = length(fromCenter);
    
    // Direction from center, normalized
    vec2 dir = normalize(fromCenter + 0.0001);
    
    // Refraction is stronger at edges (like looking through curved glass)
    // Use a sine-based curve for more natural glass-like distortion
    float refractionAmount = edgeMask * sin(edgeMask * PI * 0.5);
    
    // Add subtle wave distortion for liquid feel
    float wave = sin(dist * 8.0 + time * 0.5) * 0.1 + 1.0;
    
    return dir * refractionAmount * refractionStrength * wave;
}

// ============================================================================
// 3D BORDER REFRACTION - Creates depth illusion at edges
// ============================================================================

// Calculate border refraction for 3D depth effect
// Simulates light bending through the thick edge of glass
vec2 getBorderRefraction(vec2 uv, float borderWidth) {
    float edgeDist = getEdgeDistance(uv);
    vec2 edgeNormal = getEdgeNormal(uv);
    
    // Define the border zone with soft falloff
    float innerEdge = -borderWidth;
    float outerEdge = 0.0;
    
    // Smooth falloff factor (1.0 in border, fades to 0 outside)
    // Use smoothstep for gradual transition at inner edge
    float innerFalloff = smoothstep(innerEdge - borderWidth * 0.5, innerEdge + borderWidth * 0.3, edgeDist);
    float outerFalloff = 1.0 - smoothstep(outerEdge - borderWidth * 0.1, outerEdge, edgeDist);
    float falloff = innerFalloff * outerFalloff;
    
    // Normalized position within border (0 = inner edge, 1 = outer edge)
    float borderPos = clamp((edgeDist - innerEdge) / (outerEdge - innerEdge), 0.0, 1.0);
    
    // Create a smooth lens-like refraction profile
    // Use smoothstep-based curve instead of sin for softer transitions
    float refractionProfile = borderPos * (1.0 - borderPos) * 4.0; // Parabolic, peaks at 0.5
    
    // Stronger asymmetry for more visible distortion
    float asymmetry = mix(0.7, 1.6, borderPos);
    refractionProfile *= asymmetry;
    
    // Smooth direction change from inward to outward
    float refractionDir = smoothstep(0.0, 1.0, borderPos) * 2.0 - 1.0;
    
    // INCREASED strength for more visible liquid warping
    float strength = refractionProfile * refractionDir * refractionStrength * 4.0 * falloff;
    
    return edgeNormal * strength;
}

// Enhanced refraction for liquid flowing effect across entire surface
vec2 getLiquidRefraction(vec2 uv, float borderWidth) {
    vec2 center = vec2(0.5);
    vec2 fromCenter = uv - center;
    float dist = length(fromCenter);
    
    // Get edge distance for varying refraction
    float edgeDist = getEdgeDistance(uv);
    vec2 edgeNormal = getEdgeNormal(uv);
    
    // Combine radial and edge-based refraction for flowing liquid effect
    vec2 radialDir = normalize(fromCenter + 0.0001);
    
    // Distance-based refraction (stronger near edges)
    float distFactor = smoothstep(0.0, 0.5, dist);
    
    // Static wave pattern for liquid appearance (no animation)
    float wave1 = sin(dist * 10.0 + uv.x * 5.0) * 0.5 + 0.5;
    float wave2 = cos(dist * 8.0 + uv.y * 5.0) * 0.5 + 0.5;
    float wavePattern = mix(wave1, wave2, 0.5);
    
    // Combine directions for complex liquid flow
    vec2 flowDir = mix(radialDir, edgeNormal, 0.3);
    
    // Variable strength across surface
    float flowStrength = distFactor * wavePattern * refractionStrength * 2.5;
    
    return flowDir * flowStrength;
}

// Sample with border refraction for 3D depth
vec3 sampleWithBorderRefraction(vec2 uv, vec2 texelSize, float borderWidth) {
    vec2 borderOffset = getBorderRefraction(uv, borderWidth);
    vec2 sampleUV = clamp(uv + borderOffset, 0.001, 0.999);
    return texture(tex, sampleUV).rgb;
}

// Chromatic border refraction - each color channel refracts differently
vec3 chromaticBorderSample(vec2 uv, vec2 texelSize, float borderWidth) {
    vec2 borderOffset = getBorderRefraction(uv, borderWidth);
    vec2 edgeNormal = getEdgeNormal(uv);
    
    // Slight chromatic separation at the border
    float caStrength = chromaticAberration * 0.5;
    vec2 offsetR = borderOffset + edgeNormal * caStrength * 0.8;
    vec2 offsetG = borderOffset;
    vec2 offsetB = borderOffset - edgeNormal * caStrength * 1.2;
    
    float r = texture(tex, clamp(uv + offsetR, 0.001, 0.999)).r;
    float g = texture(tex, clamp(uv + offsetG, 0.001, 0.999)).g;
    float b = texture(tex, clamp(uv + offsetB, 0.001, 0.999)).b;
    
    return vec3(r, g, b);
}

// ============================================================================
// BLUR FUNCTION - Gaussian approximation
// ============================================================================

vec3 gaussianBlur(vec2 uv, vec2 texelSize, float strength) {
    // 9-tap Gaussian blur
    vec3 result = texture(tex, uv).rgb * 0.1633;
    
    vec2 off1 = texelSize * strength;
    vec2 off2 = texelSize * strength * 2.0;
    
    result += texture(tex, uv + vec2(off1.x, 0.0)).rgb * 0.1531;
    result += texture(tex, uv - vec2(off1.x, 0.0)).rgb * 0.1531;
    result += texture(tex, uv + vec2(0.0, off1.y)).rgb * 0.1531;
    result += texture(tex, uv - vec2(0.0, off1.y)).rgb * 0.1531;
    result += texture(tex, uv + vec2(off2.x, 0.0)).rgb * 0.0561;
    result += texture(tex, uv - vec2(off2.x, 0.0)).rgb * 0.0561;
    result += texture(tex, uv + vec2(0.0, off2.y)).rgb * 0.0561;
    result += texture(tex, uv - vec2(0.0, off2.y)).rgb * 0.0561;
    
    return result;
}

// Simpler 5-tap blur for performance with bounds clamping
vec3 fastBlur(vec2 uv, vec2 texelSize, float strength) {
    // Clamp all samples to valid UV range to prevent flickering
    vec2 off1 = vec2(1.3846153846) * texelSize * strength;
    vec2 off2 = vec2(3.2307692308) * texelSize * strength;
    
    vec3 result = texture(tex, clamp(uv, 0.0, 1.0)).rgb * 0.2270270270;
    result += texture(tex, clamp(uv + off1, 0.0, 1.0)).rgb * 0.3162162162;
    result += texture(tex, clamp(uv - off1, 0.0, 1.0)).rgb * 0.3162162162;
    result += texture(tex, clamp(uv + off2, 0.0, 1.0)).rgb * 0.0702702703;
    result += texture(tex, clamp(uv - off2, 0.0, 1.0)).rgb * 0.0702702703;
    
    return result;
}

// ============================================================================
// COLOR SMOOTHING - Create water-like fluid appearance
// ============================================================================

// Smooth colors to create flowing gradients instead of sharp patterns
vec3 waterBlend(vec2 uv, vec2 texelSize, float radius) {
    vec3 result = vec3(0.0);
    float totalWeight = 0.0;
    
    // Sample in a wider radius to blend colors smoothly
    float r = radius * 8.0;
    
    // Center sample
    vec3 center = texture(tex, clamp(uv, 0.0, 1.0)).rgb;
    result += center * 0.25;
    totalWeight += 0.25;
    
    // Ring 1 - close samples
    result += texture(tex, clamp(uv + vec2(r, 0.0) * texelSize, 0.0, 1.0)).rgb * 0.12;
    result += texture(tex, clamp(uv - vec2(r, 0.0) * texelSize, 0.0, 1.0)).rgb * 0.12;
    result += texture(tex, clamp(uv + vec2(0.0, r) * texelSize, 0.0, 1.0)).rgb * 0.12;
    result += texture(tex, clamp(uv - vec2(0.0, r) * texelSize, 0.0, 1.0)).rgb * 0.12;
    totalWeight += 0.48;
    
    // Ring 2 - medium samples (diagonals)
    float r2 = r * 0.707; // sqrt(2)/2
    result += texture(tex, clamp(uv + vec2(r2, r2) * texelSize, 0.0, 1.0)).rgb * 0.08;
    result += texture(tex, clamp(uv - vec2(r2, r2) * texelSize, 0.0, 1.0)).rgb * 0.08;
    result += texture(tex, clamp(uv + vec2(r2, -r2) * texelSize, 0.0, 1.0)).rgb * 0.08;
    result += texture(tex, clamp(uv - vec2(r2, -r2) * texelSize, 0.0, 1.0)).rgb * 0.08;
    totalWeight += 0.32;
    
    // Ring 3 - far samples for color flow
    float r3 = r * 1.5;
    result += texture(tex, clamp(uv + vec2(r3, 0.0) * texelSize, 0.0, 1.0)).rgb * 0.03;
    result += texture(tex, clamp(uv - vec2(r3, 0.0) * texelSize, 0.0, 1.0)).rgb * 0.03;
    result += texture(tex, clamp(uv + vec2(0.0, r3) * texelSize, 0.0, 1.0)).rgb * 0.03;
    result += texture(tex, clamp(uv - vec2(0.0, r3) * texelSize, 0.0, 1.0)).rgb * 0.03;
    totalWeight += 0.12;
    
    return result / totalWeight;
}

// Multi-pass smoothing for water-like fluidity
vec3 fluidSmooth(vec2 uv, vec2 texelSize, float strength) {
    // First pass - wide color averaging
    vec3 smooth1 = waterBlend(uv, texelSize, strength);
    
    // Second pass - blend with nearby colors for flow
    vec3 smooth2 = waterBlend(uv, texelSize, strength * 0.5);
    
    // Combine both passes for smooth gradients
    return mix(smooth2, smooth1, 0.5);
}

// ============================================================================
// CHROMATIC ABERRATION
// ============================================================================

vec3 chromaticSample(vec2 uv, vec2 texelSize, float edgeMask) {
    // Different refraction amounts for each color channel
    // Red bends least, blue bends most (like real glass)
    float caAmount = chromaticAberration * edgeMask;
    
    vec2 center = vec2(0.5);
    vec2 dir = normalize(uv - center + 0.0001);
    
    vec2 offsetR = dir * caAmount * 0.8;
    vec2 offsetG = vec2(0.0);  // Green is reference
    vec2 offsetB = dir * caAmount * 1.2;
    
    // Clamp all samples to prevent edge artifacts
    float r = texture(tex, clamp(uv + offsetR, 0.0, 1.0)).r;
    float g = texture(tex, clamp(uv + offsetG, 0.0, 1.0)).g;
    float b = texture(tex, clamp(uv + offsetB, 0.0, 1.0)).b;
    
    return vec3(r, g, b);
}

// ============================================================================
// FRESNEL EFFECT - Edge glow based on viewing angle
// ============================================================================

float fresnelEffect(vec2 uv) {
    vec2 center = vec2(0.5);
    vec2 pos = uv - center;
    
    // Distance from center, normalized
    float dist = length(pos) * 2.0;
    
    // Fresnel approximation: stronger reflection at grazing angles
    // F = F0 + (1 - F0) * (1 - cos(theta))^5
    float fresnel = pow(dist, 3.0);
    
    // Apply edge mask to limit to actual edges
    float edgeMask = getEdgeMask(uv, edgeThickness);
    
    return fresnel * edgeMask * fresnelStrength;
}

// ============================================================================
// SPECULAR HIGHLIGHTS - Sharp light reflections
// ============================================================================

float specularHighlight(vec2 uv) {
    // Simulate light coming from top-left
    vec2 lightDir = normalize(vec2(-0.7, -0.7));
    vec2 center = vec2(0.5);
    vec2 pos = uv - center;
    
    // Dot product with light direction
    float highlight = dot(normalize(pos + 0.0001), lightDir);
    
    // Sharp falloff for specular look
    highlight = pow(max(highlight, 0.0), 16.0);
    
    // Only show on edges
    float edgeMask = getEdgeMask(uv, edgeThickness * 0.5);
    
    // Add secondary highlight from bottom-right for depth
    vec2 lightDir2 = normalize(vec2(0.7, 0.7));
    float highlight2 = dot(normalize(pos + 0.0001), lightDir2);
    highlight2 = pow(max(highlight2, 0.0), 24.0) * 0.5;
    
    return (highlight + highlight2) * edgeMask * specularStrength;
}

// ============================================================================
// MAIN SHADER
// ============================================================================

void main() {
    vec2 uv = v_texcoord;
    vec2 texelSize = 1.0 / fullSize;
    
    // Get rounded corner alpha - discard pixels outside rounded rect
    float cornerAlpha = getRoundedAlpha(uv);
    if (cornerAlpha < 0.001) {
        discard;
    }
    
    // Calculate edge distance and masks
    float edgeDist = getEdgeDistance(uv);
    float edgeMask = getEdgeMask(uv, edgeThickness);
    
    // Define border zone width (in UV space)
    float borderWidth = edgeThickness * 1.5;
    
    // Smooth border blend factor - no hard edges
    // Gradually transitions from interior (0) to full border effect (1) to edge
    float borderBlend = smoothstep(-borderWidth * 1.5, -borderWidth * 0.3, edgeDist) 
                      * (1.0 - smoothstep(-borderWidth * 0.1, 0.0, edgeDist));
    
    // ========================================
    // 1. LIQUID REFRACTION - Visible warping
    // ========================================
    // Get border refraction for 3D depth at edges
    vec2 borderRefract = getBorderRefraction(uv, borderWidth);
    vec2 refractedUV = clamp(uv + borderRefract, 0.001, 0.999);
    
    // ========================================
    // 2. CHROMATIC DISPERSION - Color separation
    // ========================================
    vec2 edgeNormal = getEdgeNormal(uv);
    float chromaStrength = length(borderRefract) * chromaticAberration * 2.0;
    
    float r = texture(tex, clamp(refractedUV - edgeNormal * chromaStrength * 0.8, 0.0, 1.0)).r;
    float g = texture(tex, clamp(refractedUV, 0.0, 1.0)).g;
    float b = texture(tex, clamp(refractedUV + edgeNormal * chromaStrength * 1.2, 0.0, 1.0)).b;
    
    vec3 refractedColor = vec3(r, g, b);
    
    // ========================================
    // 3. BLUR - Frosted glass effect
    // ========================================
    vec3 blurredColor = fastBlur(refractedUV, texelSize, blurStrength);
    
    // Mix refracted and blurred
    vec3 glassColor = mix(blurredColor, refractedColor, 0.4);
    
    // ========================================
    // 4. SUBTLE EDGE DEPTH
    // ========================================
    // Smooth depth variation based on edge proximity
    float depthFactor = smoothstep(-borderWidth, 0.0, edgeDist);
    
    // Very subtle brightness variation (no hard lines)
    float depthBrightness = mix(0.98, 1.02, depthFactor);
    glassColor *= depthBrightness;
    
    // ========================================
    // 7. FINAL ADJUSTMENTS
    // ========================================
    // Slight cool tint for glass
    vec3 glassTint = vec3(0.99, 0.995, 1.0);
    vec3 finalColor = glassColor * glassTint;
    
    // Clamp to valid range
    finalColor = clamp(finalColor, 0.0, 1.0);
     
    fragColor = vec4(finalColor, glassOpacity * cornerAlpha);
}
)GLSL"},
};
