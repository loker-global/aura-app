# SHADER-SPEC — Metal Rendering Specification

⸻

## 0. PURPOSE

Define Metal shader implementation for OrbRenderer.

This ensures:
- Surface deformation ≤ 3% radius
- Calm, material feel (not digital)
- 60 fps minimum on Apple Silicon
- Minimal lighting (soft rim, no neon)

⸻

## 1. RENDERING PIPELINE

### Architecture
**Forward rendering** (single pass)
- Vertex shader: deformation + lighting
- Fragment shader: shading + color

**Why forward?**
- Simple (one geometry, one light)
- Efficient (no G-buffer overhead)
- Minimal state (no complex material system)

---

## 2. GEOMETRY

### Base Mesh
**Icosphere** (subdivided icosahedron)
- Subdivision level: 5
- Vertex count: 2562
- Triangle count: 5120
- Topology: uniform triangulation (no poles/singularities)

**Generation:**
- Pre-computed at build time (baked into binary)
- Stored as position-only buffer (normals computed in shader)

### Vertex Format
```metal
struct Vertex {
    float3 position [[attribute(0)]];
};
```

**Normals:** Computed from deformed position (ensures smooth shading)

---

## 3. DEFORMATION ALGORITHM

### Method
**Physics-driven vertex displacement**

### Vertex Shader Logic
```metal
vertex VertexOut vertex_main(Vertex in [[stage_in]],
                             constant Uniforms& uniforms [[buffer(1)]]) {
    // Get base position (normalized direction from center)
    float3 baseDirection = normalize(in.position);
    
    // Radial deformation (from physics RMS force)
    float radialOffset = uniforms.radialExpansion; // 0.0 to 0.03
    
    // Micro-ripple deformation (from physics ZCR force)
    float rippleNoise = simplexNoise3D(baseDirection * 5.0 + uniforms.time);
    float rippleOffset = uniforms.rippleAmplitude * rippleNoise; // ±0.005
    
    // Combined deformation
    float totalOffset = radialOffset + rippleOffset;
    totalOffset = clamp(totalOffset, -0.03, 0.03); // hard 3% clamp
    
    // Apply deformation
    float3 deformedPosition = baseDirection * (uniforms.baseRadius + totalOffset);
    
    // Transform to clip space
    float4 clipPosition = uniforms.mvpMatrix * float4(deformedPosition, 1.0);
    
    // Compute normal (per-vertex, smooth shading)
    float3 normal = normalize(deformedPosition); // sphere normal = position
    
    VertexOut out;
    out.position = clipPosition;
    out.worldPosition = deformedPosition;
    out.normal = normal;
    return out;
}
```

### Deformation Sources
1. **Radial expansion** (uniform, from RMS energy)
2. **Micro-ripples** (spatial noise, from ZCR)

**No impulse deformation in shader** (impulses affect physics, shader follows physics state)

---

## 4. LIGHTING MODEL

### Approach
**Simplified Phong** (not PBR)

**Why not PBR?**
- Overkill for single object
- AURA aesthetic is soft, not photorealistic
- Performance budget (mobile)

### Light Setup
**Single rim light**
- Type: Directional
- Position: Behind and above camera (45° elevation)
- Color: Soft white (#FFFFFF, intensity 0.6)

**No fill light** (intentional darkness on front face)

### Shader Lighting
```metal
fragment float4 fragment_main(VertexOut in [[stage_in]],
                               constant Uniforms& uniforms [[buffer(0)]]) {
    // Material properties
    float3 albedo = uniforms.orbColor; // #E6E7E9 (bone/off-white)
    float3 lightDir = normalize(uniforms.lightDirection); // rim light direction
    float3 viewDir = normalize(uniforms.cameraPosition - in.worldPosition);
    float3 normal = normalize(in.normal);
    
    // Diffuse (Lambert)
    float diffuse = max(dot(normal, lightDir), 0.0);
    diffuse = pow(diffuse, 1.5); // slightly tighter falloff
    
    // Specular (Blinn-Phong, subtle)
    float3 halfVector = normalize(lightDir + viewDir);
    float specular = pow(max(dot(normal, halfVector), 0.0), 8.0);
    specular *= 0.15; // low intensity (no harsh highlights)
    
    // Ambient (soft base illumination)
    float ambient = 0.2;
    
    // Combine
    float3 color = albedo * (ambient + diffuse * 0.6) + float3(specular);
    
    return float4(color, 1.0);
}
```

### Parameters
```swift
// Lighting
let lightDirection = normalize(float3(0.3, 0.5, -1.0)) // behind-right-above
let lightColor = float3(1.0, 1.0, 1.0)
let lightIntensity: Float = 0.6

// Material
let orbColor = float3(0.902, 0.906, 0.914) // #E6E7E9
let specularPower: Float = 8.0
let specularIntensity: Float = 0.15
let ambientIntensity: Float = 0.2
```

---

## 5. COLOR & MATERIAL

### Orb Color
**Default:** `#E6E7E9` (bone/off-white)

**Linear RGB (shader space):**
```swift
let orbColor = float3(0.902, 0.906, 0.914) // sRGB → linear conversion
```

**Color Space:**
- All shader calculations in **linear RGB**
- Output framebuffer: **sRGB** (automatic gamma correction)

**Rationale:**
- Linear space required for correct lighting math
- sRGB output matches display expectations

### Background
**Solid color:** `#0E0F12` (near-black)

**Rendering:**
- Clear color (no skybox, no gradient)
- Applied before orb render pass

---

## 6. NOISE FUNCTION

### Purpose
Micro-ripple spatial variation (from ZCR)

### Implementation
**3D Simplex Noise**

**Why simplex over Perlin?**
- Faster (fewer gradient lookups)
- No directional artifacts
- Smooth interpolation

**Source:**
- Inline Metal implementation (Stefan Gustavson's algorithm)
- ~30 lines, no external dependencies

**Usage:**
```metal
float rippleNoise = simplexNoise3D(worldPosition * frequency + time * speed);
```

**Parameters:**
```swift
let noiseFrequency: Float = 5.0 // spatial detail
let noiseSpeed: Float = 0.2 // temporal drift
```

---

## 7. CAMERA & PROJECTION

### Camera Setup
**Orthographic projection** (no perspective distortion)

**Why orthographic?**
- Orb size constant regardless of distance
- No foreshortening (cleaner visual)
- Aligns with "presence, not space" philosophy

**Fallback:** Perspective with very long focal length (minimal distortion)

### Camera Position
```swift
let cameraPosition = float3(0, 0, -3.0) // 3 units back from orb
let cameraTarget = float3(0, 0, 0) // looking at orb center
let cameraUp = float3(0, 1, 0) // Y-up
```

### View Frustum
```swift
// Orthographic
let orthoWidth: Float = 2.5 // orb fits comfortably (1.0 radius + margin)
let orthoHeight: Float = 2.5
let nearPlane: Float = 0.1
let farPlane: Float = 10.0
```

### No Camera Movement
- Fixed position (no dollying, panning, rotation)
- Orb is only moving element

---

## 8. RENDER STATE

### Depth Testing
**Enabled** (orb self-occludes correctly)

```swift
depthStencilState.depthCompareFunction = .less
depthStencilState.isDepthWriteEnabled = true
```

### Culling
**Back-face culling enabled** (performance optimization)

```swift
renderPipelineState.cullMode = .back
renderPipelineState.frontFaceWinding = .counterClockwise
```

### Blending
**Disabled** (orb is opaque)

### MSAA (Anti-Aliasing)
**4× MSAA** (smooth edges)

**Fallback:** 2× if performance issues

---

## 9. PERFORMANCE BUDGET

### Target
- **Apple Silicon (M1+):** 60 fps minimum, 120 fps preferred
- **Intel Macs (2018+):** 60 fps minimum, 30 fps acceptable (degraded)

### Optimization
- Single draw call (2562 vertices, 5120 triangles)
- No texture lookups (procedural only)
- Inline noise function (no texture-based noise)
- Minimal uniform updates (only changed values)

### Profiling Targets
- Vertex shader: <0.5ms
- Fragment shader: <1.0ms
- Total frame time: <16ms (60 fps)

---

## 10. UNIFORMS

### Structure
```metal
struct Uniforms {
    float4x4 mvpMatrix;         // Model-View-Projection
    float3 cameraPosition;
    float3 lightDirection;
    float3 orbColor;
    
    float baseRadius;           // 1.0
    float radialExpansion;      // 0.0 to 0.03 (from physics)
    float rippleAmplitude;      // 0.0 to 0.005 (from physics)
    float time;                 // for noise animation
};
```

### Update Frequency
- **Per frame:** mvpMatrix, radialExpansion, rippleAmplitude, time
- **Static:** cameraPosition, lightDirection, orbColor, baseRadius

---

## 11. EXPORT RENDERING

### Offline Rendering (OrbExporter)
**Same shader, headless Metal device**

### Differences
- No display sync (render as fast as possible)
- Higher MSAA (8× for export quality)
- Optional higher resolution (4K export)

### Frame Capture
```swift
// Render to texture
let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .bgra8Unorm_srgb,
    width: exportWidth,
    height: exportHeight,
    mipmapped: false
)
textureDescriptor.usage = [.renderTarget, .shaderRead]

// Render orb to texture
// Read back to CPU
// Feed to AVAssetWriter
```

---

## 12. DEBUGGING AIDS

### Wireframe Mode
**Debug-only toggle**

```metal
// Fragment shader
if (uniforms.debugWireframe) {
    return float4(0.0, 1.0, 0.0, 1.0); // green edges
}
```

### Normal Visualization
**Debug-only toggle**

```metal
if (uniforms.debugNormals) {
    return float4(normal * 0.5 + 0.5, 1.0); // normal map colors
}
```

---

## 13. COLOR SPACE NOTES

### Input (Physics)
- Forces in normalized scale (0.0 to 1.0)

### Shader (Linear RGB)
- All lighting math in linear space
- sRGB colors converted to linear: `pow(sRGB, 2.2)`

### Output (sRGB Framebuffer)
- Automatic gamma correction by GPU
- No manual conversion needed

---

## FINAL PRINCIPLE

Rendering must serve presence, not spectacle.

If the orb feels impressive, the shader has failed.

⸻

**Status:** Shader spec locked
