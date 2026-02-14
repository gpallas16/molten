#version 300 es
precision highp float;

/*
 * Liquid Glass Fragment Shader
 * Based on OverShifted/LiquidGlass implementation
 * Adapted for arbitrary window shapes using SDF
 * 
 * Refraction profile: f(x) = 1 - b * (c * e)^(-d * x - a)
 */

// Uniforms
uniform sampler2D tex;
uniform vec2 topLeft;
uniform vec2 fullSize;
uniform vec2 fullSizeUntransformed;
uniform float radius;
uniform float time;

// Configurable parameters (matching OverShifted defaults from image)
uniform float blurStrength;        // Not used in OverShifted style - blur done externally
uniform float refractionStrength;  // Maps to fPower
uniform float chromaticAberration; // Not in original, kept for compatibility
uniform float fresnelStrength;     // Maps to glowWeight
uniform float specularStrength;    // Maps to glowBias
uniform float glassOpacity;        // Overall opacity
uniform float edgeThickness;       // Maps to powerFactor for shape

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

// Constants
const float M_E = 2.718281828459045;
const float M_PI = 3.14159265359;
const float AA_EDGE = 0.002;

// ============================================================================
// Refraction parameters (from image defaults)
// f(x) = 1 - b * (c * e)^(-d * x - a)
// ============================================================================
const float u_a = 0.700;
const float u_b = 2.300;
const float u_c = 2.235;
const float u_d = 3.077;
const float u_fPower = 1.000;
const float u_powerFactor = 2.0;  // Shape power (superellipse exponent)
const float u_noise = 0.060;

// Glow parameters (from image)
const float u_glowWeight = 0.380;
const float u_glowBias = -0.097;
const float u_glowEdge0 = 0.500;
const float u_glowEdge1 = -0.500;

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

// Signed distance to a superellipse (generalized rounded shape)
// n = 2.0 gives a circle/ellipse, n > 2 gives squircle, n < 2 gives star
float sdSuperellipse(vec2 p, float n, float r) {
    vec2 p_abs = abs(p);
    
    // Numerator: |x|^n + |y|^n - r^n
    float numerator = pow(p_abs.x, n) + pow(p_abs.y, n) - pow(r, n);
    
    // Denominator: n * sqrt(|x|^(2n-2) + |y|^(2n-2))
    float den_x = pow(p_abs.x + 0.00001, 2.0 * n - 2.0);
    float den_y = pow(p_abs.y + 0.00001, 2.0 * n - 2.0);
    float denominator = n * sqrt(den_x + den_y) + 0.00001;
    
    return numerator / denominator;
}

// Standard rounded box SDF for window shape
float roundedBoxSDF(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Refraction function from OverShifted
// f(x) = 1 - b * (c * e)^(-d * x - a)
float refractionF(float x) {
    return 1.0 - u_b * pow(u_c * M_E, -u_d * x - u_a);
}

// Random noise
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// Glow function - directional shine based on angle
float Glow(vec2 uv) {
    return sin(atan(uv.y * 2.0 - 1.0, uv.x * 2.0 - 1.0) - 0.5);
}

// ============================================================================
// SHAPE DISTANCE CALCULATION
// Adapts to window shape using rounded rectangle SDF
// ============================================================================

float getShapeDistance(vec2 uv) {
    vec2 center = vec2(0.5);
    vec2 p = (uv - center) * 2.0;  // Map to -1..1
    
    float aspectRatio = fullSize.x / fullSize.y;
    
    // Scale to match window aspect ratio
    vec2 scaledP = p * vec2(aspectRatio, 1.0);
    vec2 halfSize = vec2(aspectRatio, 1.0);
    
    // Radius in normalized space
    float uvRadius = (radius / fullSize.y) * 2.0;
    
    // Use rounded box SDF for window shape
    return roundedBoxSDF(scaledP, halfSize, uvRadius);
}

// For superellipse-based inner distance (used in refraction)
float getSuperellipseDistance(vec2 p, float power) {
    // p should be in -1..1 range
    return sdSuperellipse(p, power, 1.0);
}

// ============================================================================
// MAIN LIQUID GLASS FUNCTION
// Based on OverShifted's LiquidGlass() function
// Adapted to use rounded rectangle SDF for proper rectangular refraction
// ============================================================================

vec4 LiquidGlass(vec2 uv) {
    vec2 center = vec2(0.5);
    
    // Get window shape distance for clipping
    float shapeDist = getShapeDistance(uv);
    
    // Discard pixels outside the window shape
    if (shapeDist > 0.0) {
        discard;
    }
    
    // Use the actual rounded rectangle distance for refraction
    // This ensures refraction follows the window shape, not a circle
    float aspectRatio = fullSize.x / fullSize.y;
    
    // Distance from edge (positive inside) - use rounded rect SDF
    // shapeDist is negative inside, so -shapeDist is positive inside
    float dist = -shapeDist;
    
    // Normalize distance relative to window size for consistent refraction
    // Use the smaller dimension as reference
    float normalizedDist = dist * min(aspectRatio, 1.0 / aspectRatio) * 2.0;
    
    // Apply refraction function
    float fx = refractionF(normalizedDist);
    
    // Map UV to centered coordinates for scaling
    vec2 p = (uv - center) * 2.0;
    
    // Scale the sample position based on refraction
    // The scaling pulls inward from edges uniformly
    vec2 sampleP = p * pow(fx, u_fPower);
    
    // Calculate target UV coordinates
    vec2 targetUV = sampleP * 0.5 + vec2(0.5);
    
    // Clamp to valid texture coordinates
    targetUV = clamp(targetUV, 0.001, 0.999);
    
    // Sample the background texture
    vec4 color = texture(tex, targetUV);
    
    // Add noise for texture
    vec4 noise = vec4(vec3(rand(gl_FragCoord.xy * 1e-3) - 0.5), 0.0);
    color += noise * u_noise;
    
    // Apply glow effect
    float glowValue = Glow(uv);
    float glowMask = smoothstep(u_glowEdge0, u_glowEdge1, normalizedDist);
    float mul = glowValue * u_glowWeight * glowMask + 1.0 + u_glowBias;
    
    color.rgb *= mul;
    
    return color;
}

// ============================================================================
// MAIN
// ============================================================================

void main() {
    vec2 uv = v_texcoord;
    
    // Get window shape alpha for smooth edges
    float shapeDist = getShapeDistance(uv);
    float cornerAlpha = 1.0 - smoothstep(-AA_EDGE, AA_EDGE, shapeDist);
    
    if (cornerAlpha < 0.001) {
        discard;
    }
    
    // Apply liquid glass effect (refraction + blur sampling)
    vec4 color = LiquidGlass(uv);
    
    // Apply opacity and corner smoothing
    color.a = glassOpacity * cornerAlpha;
    
    // Clamp final color
    color.rgb = clamp(color.rgb, 0.0, 1.0);
    
    fragColor = color;
}
