#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct Vertex {
    float3 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
};

struct Uniforms {
    float4x4 mvpMatrix;
    float3 cameraPosition;
    float3 lightDirection;
    float3 orbColor;
    float baseRadius;
    float radialExpansion;
    float rippleAmplitude;
    float time;
};

// MARK: - Noise Functions (Simplex Noise 3D)

// Permutation polynomial
float3 mod289(float3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float4 mod289(float4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float4 permute(float4 x) {
    return mod289(((x * 34.0) + 1.0) * x);
}

float4 taylorInvSqrt(float4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

float simplexNoise3D(float3 v) {
    const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);
    const float4 D = float4(0.0, 0.5, 1.0, 2.0);
    
    // First corner
    float3 i  = floor(v + dot(v, C.yyy));
    float3 x0 = v - i + dot(i, C.xxx);
    
    // Other corners
    float3 g = step(x0.yzx, x0.xyz);
    float3 l = 1.0 - g;
    float3 i1 = min(g.xyz, l.zxy);
    float3 i2 = max(g.xyz, l.zxy);
    
    float3 x1 = x0 - i1 + C.xxx;
    float3 x2 = x0 - i2 + C.yyy;
    float3 x3 = x0 - D.yyy;
    
    // Permutations
    i = mod289(i);
    float4 p = permute(permute(permute(
        i.z + float4(0.0, i1.z, i2.z, 1.0))
        + i.y + float4(0.0, i1.y, i2.y, 1.0))
        + i.x + float4(0.0, i1.x, i2.x, 1.0));
    
    // Gradients
    float n_ = 0.142857142857;
    float3 ns = n_ * D.wyz - D.xzx;
    
    float4 j = p - 49.0 * floor(p * ns.z * ns.z);
    
    float4 x_ = floor(j * ns.z);
    float4 y_ = floor(j - 7.0 * x_);
    
    float4 x = x_ * ns.x + ns.yyyy;
    float4 y = y_ * ns.x + ns.yyyy;
    float4 h = 1.0 - abs(x) - abs(y);
    
    float4 b0 = float4(x.xy, y.xy);
    float4 b1 = float4(x.zw, y.zw);
    
    float4 s0 = floor(b0) * 2.0 + 1.0;
    float4 s1 = floor(b1) * 2.0 + 1.0;
    float4 sh = -step(h, float4(0.0));
    
    float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
    
    float3 p0 = float3(a0.xy, h.x);
    float3 p1 = float3(a0.zw, h.y);
    float3 p2 = float3(a1.xy, h.z);
    float3 p3 = float3(a1.zw, h.w);
    
    // Normalize gradients
    float4 norm = taylorInvSqrt(float4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;
    
    // Mix final noise value
    float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m * m, float4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

// MARK: - Vertex Shader

vertex VertexOut vertex_main(Vertex in [[stage_in]],
                              constant Uniforms& uniforms [[buffer(1)]]) {
    // Get base position (normalized direction from center)
    float3 baseDirection = normalize(in.position);
    
    // Radial deformation (from physics RMS force)
    float radialOffset = uniforms.radialExpansion;
    
    // Micro-ripple deformation (from physics ZCR force)
    float noiseFrequency = 5.0;
    float noiseSpeed = 0.2;
    float rippleNoise = simplexNoise3D(baseDirection * noiseFrequency + uniforms.time * noiseSpeed);
    float rippleOffset = uniforms.rippleAmplitude * rippleNoise;
    
    // Combined deformation (hard 3% clamp)
    float totalOffset = radialOffset + rippleOffset;
    totalOffset = clamp(totalOffset, -0.03, 0.03);
    
    // Apply deformation
    float3 deformedPosition = baseDirection * (uniforms.baseRadius + totalOffset);
    
    // Transform to clip space
    float4 clipPosition = uniforms.mvpMatrix * float4(deformedPosition, 1.0);
    
    // Compute normal (sphere normal = position)
    float3 normal = normalize(deformedPosition);
    
    VertexOut out;
    out.position = clipPosition;
    out.worldPosition = deformedPosition;
    out.normal = normal;
    return out;
}

// MARK: - Fragment Shader

fragment float4 fragment_main(VertexOut in [[stage_in]],
                               constant Uniforms& uniforms [[buffer(0)]]) {
    // Material properties
    float3 albedo = uniforms.orbColor;
    float3 lightDir = normalize(uniforms.lightDirection);
    float3 viewDir = normalize(uniforms.cameraPosition - in.worldPosition);
    float3 normal = normalize(in.normal);
    
    // Diffuse (Lambert with tighter falloff)
    float diffuse = max(dot(normal, lightDir), 0.0);
    diffuse = pow(diffuse, 1.5);
    
    // Specular (Blinn-Phong, subtle)
    float3 halfVector = normalize(lightDir + viewDir);
    float specular = pow(max(dot(normal, halfVector), 0.0), 8.0);
    specular *= 0.15;
    
    // Ambient
    float ambient = 0.2;
    
    // Combine
    float3 color = albedo * (ambient + diffuse * 0.6) + float3(specular);
    
    return float4(color, 1.0);
}
