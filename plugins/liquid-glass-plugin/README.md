# 🍎 Liquid Glass Plugin for Hyprland

 rm -f liquid-glass.so src/shaders.hpp && make && hyprctl plugin unload $(pwd)/liquid-glass.so && hyprctl plugin load $(pwd)/liquid-glass.so



S
A stunning Apple-style **Liquid Glass** effect for Hyprland, inspired by iOS 26's revolutionary design language.

![Liquid Glass Effect](https://img.shields.io/badge/Effect-Liquid%20Glass-blue?style=for-the-badge)
![Hyprland Plugin](https://img.shields.io/badge/Hyprland-Plugin-purple?style=for-the-badge)

## ✨ Features

This plugin recreates Apple's Liquid Glass aesthetic with physically-accurate visual effects:

| Effect | Description |
|--------|-------------|
| **🔮 Edge Refraction** | Light bends dramatically at window edges, like looking through curved glass |
| **🌈 Chromatic Aberration** | RGB channels separate slightly at edges, creating subtle rainbow fringes |
| **💫 Fresnel Effect** | Edges glow brighter based on viewing angle (real physics!) |
| **✨ Specular Highlights** | Sharp, mirror-like light reflections dance across the glass |
| **🌫️ Interior Blur** | Subtle blur gives the illusion of glass thickness |

## 📦 Installation

### Using hyprpm (Recommended)

```bash
hyprpm add https://github.com/xiaoxigua-1/liquid-glass-plugin-hyprpm
hyprpm enable liquid-glass
```

### Manual Build

**Requirements:**
- Hyprland (with development headers)
- pkg-config
- C++23 compatible compiler (g++ or clang++)

```bash
git clone https://github.com/xiaoxigua-1/liquid-glass-plugin-hyprpm
cd liquid-glass-plugin-hyprpm
make all
```

Then load manually:
```bash
hyprctl plugin load $(pwd)/liquid-glass.so
```

## ⚙️ Configuration

Add to your `hyprland.conf`:

```conf
# ═══════════════════════════════════════════════════════════════════
#                    🍎 LIQUID GLASS CONFIGURATION
# ═══════════════════════════════════════════════════════════════════

plugin {
    liquid-glass {
        # Enable/disable the effect
        enabled = true
        
        # ─────────────────────────────────────────────────────────────
        # BLUR - Interior glass thickness effect
        # ─────────────────────────────────────────────────────────────
        # Range: 0.0 - 3.0 | Default: 1.5
        # Higher = more blur, feels like thicker glass
        blur_strength = 1.5
        
        # ─────────────────────────────────────────────────────────────
        # REFRACTION - Edge distortion intensity
        # ─────────────────────────────────────────────────────────────
        # Range: 0.0 - 0.2 | Default: 0.08
        # How much the background warps at edges
        refraction_strength = 0.08
        
        # ─────────────────────────────────────────────────────────────
        # CHROMATIC ABERRATION - Rainbow edge fringing
        # ─────────────────────────────────────────────────────────────
        # Range: 0.0 - 0.03 | Default: 0.012
        # RGB channel separation for that authentic glass look
        chromatic_aberration = 0.012
        
        # ─────────────────────────────────────────────────────────────
        # FRESNEL - Edge glow based on viewing angle
        # ─────────────────────────────────────────────────────────────
        # Range: 0.0 - 1.0 | Default: 0.4
        # Simulates how glass reflects more light at grazing angles
        fresnel_strength = 0.4
        
        # ─────────────────────────────────────────────────────────────
        # SPECULAR - Sharp light reflections
        # ─────────────────────────────────────────────────────────────
        # Range: 0.0 - 1.0 | Default: 0.3
        # Those crisp, bright spots where light bounces off
        specular_strength = 0.3
        
        # ─────────────────────────────────────────────────────────────
        # OPACITY - Overall glass transparency
        # ─────────────────────────────────────────────────────────────
        # Range: 0.0 - 1.0 | Default: 1.0
        glass_opacity = 1.0
        
        # ─────────────────────────────────────────────────────────────
        # EDGE THICKNESS - Width of the refractive edge zone
        # ─────────────────────────────────────────────────────────────
        # Range: 0.0 - 0.4 | Default: 0.15
        # How far the edge effects extend into the window
        edge_thickness = 0.15
    }
}

# ═══════════════════════════════════════════════════════════════════
#                    RECOMMENDED COMPANION SETTINGS
# ═══════════════════════════════════════════════════════════════════

decoration {
    # Rounded corners work beautifully with liquid glass
    rounding = 12
    
    # Disable default blur - we handle it ourselves
    blur {
        enabled = false
    }
    
    # Subtle shadow complements the glass effect
    shadow {
        enabled = true
        range = 20
        render_power = 3
        color = rgba(00000055)
    }
}

# Optional: window rules for specific apps
# windowrulev2 = opacity 0.9, class:^(firefox)$
```

## 🎨 Preset Configurations

### Subtle & Professional
```conf
plugin:liquid-glass {
    blur_strength = 1.0
    refraction_strength = 0.04
    chromatic_aberration = 0.006
    fresnel_strength = 0.2
    specular_strength = 0.15
}
```

### Maximum Apple Vibes
```conf
plugin:liquid-glass {
    blur_strength = 2.0
    refraction_strength = 0.12
    chromatic_aberration = 0.018
    fresnel_strength = 0.6
    specular_strength = 0.5
}
```

### Frosted Glass (No Refraction)
```conf
plugin:liquid-glass {
    blur_strength = 2.5
    refraction_strength = 0.0
    chromatic_aberration = 0.0
    fresnel_strength = 0.3
    specular_strength = 0.2
}
```

## 🔧 Troubleshooting

### Plugin fails to load
- Ensure Hyprland version matches plugin compilation
- Rebuild after Hyprland updates: `hyprpm update`

### Performance issues
- Reduce `blur_strength` (most expensive effect)
- Lower `chromatic_aberration` to 0
- Disable on specific windows with window rules

### Visual artifacts
- Adjust `edge_thickness` if edges look wrong
- Reduce `refraction_strength` if distortion is too strong

## 📜 License

MIT License - See [LICENSE](LICENSE) for details.

## 🙏 Credits

- **Original Author:** xiaoxigua-1
- **Inspiration:** Apple's iOS 26 Liquid Glass design language
- **Physics Reference:** Fresnel equations, chromatic dispersion

---

<p align="center">
  <i>Making Hyprland look like a million bucks, one window at a time.</i>
</p>
