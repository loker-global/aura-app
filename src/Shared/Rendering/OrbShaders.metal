// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// OrbShaders.metal — Metal shaders for orb rendering

#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Structures

struct VertexIn {
    float3 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
};

// MARK: - Uniforms

struct Uniforms {
    float4x4 modelViewProjectionMatrix;
    float3 cameraPosition;
    float3 lightDirection;
    float3 orbColor;
    
    float baseRadius;
    float radialExpansion;
    float rippleAmplitude;
    float time;
    
    // Debug flags
    bool debugWireframe;
    bool debugNormals;
};

// MARK: - Simplex Noise

// Permutation table
constant int perm[512] = {
    151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,
    140,36,103,30,69,142,8,99,37,240,21,10,23,190,6,148,
    247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,
    57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,
    74,165,71,134,139,48,27,166,77,146,158,231,83,111,229,122,
    60,211,133,230,220,105,92,41,55,46,245,40,244,102,143,54,
    65,25,63,161,1,216,80,73,209,76,132,187,208,89,18,169,
    200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,
    52,217,226,250,124,123,5,202,38,147,118,126,255,82,85,212,
    207,206,59,227,47,16,58,17,182,189,28,42,223,183,170,213,
    119,248,152,2,44,154,163,70,221,153,101,155,167,43,172,9,
    129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,
    218,246,97,228,251,34,242,193,238,210,144,12,191,179,162,241,
    81,51,145,235,249,14,239,107,49,192,214,31,181,199,106,157,
    184,84,204,176,115,121,50,45,127,4,150,254,138,236,205,93,
    222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180,
    // Duplicate for wrap
    151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,
    140,36,103,30,69,142,8,99,37,240,21,10,23,190,6,148,
    247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,
    57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,
    74,165,71,134,139,48,27,166,77,146,158,231,83,111,229,122,
    60,211,133,230,220,105,92,41,55,46,245,40,244,102,143,54,
    65,25,63,161,1,216,80,73,209,76,132,187,208,89,18,169,
    200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,
    52,217,226,250,124,123,5,202,38,147,118,126,255,82,85,212,
    207,206,59,227,47,16,58,17,182,189,28,42,223,183,170,213,
    119,248,152,2,44,154,163,70,221,153,101,155,167,43,172,9,
    129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,
    218,246,97,228,251,34,242,193,238,210,144,12,191,179,162,241,
    81,51,145,235,249,14,239,107,49,192,214,31,181,199,106,157,
    184,84,204,176,115,121,50,45,127,4,150,254,138,236,205,93,
    222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
};

// Gradient function
float grad3(int hash, float x, float y, float z) {
    int h = hash & 15;
    float u = h < 8 ? x : y;
    float v = h < 4 ? y : (h == 12 || h == 14 ? x : z);
    return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
}

// 3D Simplex Noise (Stefan Gustavson's algorithm)
float simplexNoise3D(float3 v) {
    const float F3 = 1.0 / 3.0;
    const float G3 = 1.0 / 6.0;
    
    // Skew input space
    float s = (v.x + v.y + v.z) * F3;
    int i = floor(v.x + s);
    int j = floor(v.y + s);
    int k = floor(v.z + s);
    
    // Unskew
    float t = (i + j + k) * G3;
    float x0 = v.x - i + t;
    float y0 = v.y - j + t;
    float z0 = v.z - k + t;
    
    // Determine simplex
    int i1, j1, k1;
    int i2, j2, k2;
    
    if (x0 >= y0) {
        if (y0 >= z0) { i1=1; j1=0; k1=0; i2=1; j2=1; k2=0; }
        else if (x0 >= z0) { i1=1; j1=0; k1=0; i2=1; j2=0; k2=1; }
        else { i1=0; j1=0; k1=1; i2=1; j2=0; k2=1; }
    } else {
        if (y0 < z0) { i1=0; j1=0; k1=1; i2=0; j2=1; k2=1; }
        else if (x0 < z0) { i1=0; j1=1; k1=0; i2=0; j2=1; k2=1; }
        else { i1=0; j1=1; k1=0; i2=1; j2=1; k2=0; }
    }
    
    float x1 = x0 - i1 + G3;
    float y1 = y0 - j1 + G3;
    float z1 = z0 - k1 + G3;
    float x2 = x0 - i2 + 2.0 * G3;
    float y2 = y0 - j2 + 2.0 * G3;
    float z2 = z0 - k2 + 2.0 * G3;
    float x3 = x0 - 1.0 + 3.0 * G3;
    float y3 = y0 - 1.0 + 3.0 * G3;
    float z3 = z0 - 1.0 + 3.0 * G3;
    
    int ii = i & 255;
    int jj = j & 255;
    int kk = k & 255;
    
    float n0, n1, n2, n3;
    
    float t0 = 0.6 - x0*x0 - y0*y0 - z0*z0;
    if (t0 < 0) n0 = 0;
    else {
        t0 *= t0;
        n0 = t0 * t0 * grad3(perm[ii + perm[jj + perm[kk]]], x0, y0, z0);
    }
    
    float t1 = 0.6 - x1*x1 - y1*y1 - z1*z1;
    if (t1 < 0) n1 = 0;
    else {
        t1 *= t1;
        n1 = t1 * t1 * grad3(perm[ii + i1 + perm[jj + j1 + perm[kk + k1]]], x1, y1, z1);
    }
    
    float t2 = 0.6 - x2*x2 - y2*y2 - z2*z2;
    if (t2 < 0) n2 = 0;
    else {
        t2 *= t2;
        n2 = t2 * t2 * grad3(perm[ii + i2 + perm[jj + j2 + perm[kk + k2]]], x2, y2, z2);
    }
    
    float t3 = 0.6 - x3*x3 - y3*y3 - z3*z3;
    if (t3 < 0) n3 = 0;
    else {
        t3 *= t3;
        n3 = t3 * t3 * grad3(perm[ii + 1 + perm[jj + 1 + perm[kk + 1]]], x3, y3, z3);
    }
    
    return 32.0 * (n0 + n1 + n2 + n3);
}

// MARK: - Vertex Shader

vertex VertexOut vertex_main(
    VertexIn in [[stage_in]],
    constant Uniforms& uniforms [[buffer(1)]]
) {
    // Get base direction (normalized position from center)
    float3 baseDirection = normalize(in.position);
    
    // Radial deformation (from physics RMS force)
    float radialOffset = uniforms.radialExpansion;
    
    // Micro-ripple deformation (from physics ZCR force)
    // Spatial noise varies across surface
    float rippleNoise = simplexNoise3D(baseDirection * 5.0 + float3(uniforms.time, 0.0, 0.0));
    float rippleOffset = uniforms.rippleAmplitude * rippleNoise;
    
    // Combined deformation (hard 3% clamp)
    float totalOffset = radialOffset + rippleOffset;
    totalOffset = clamp(totalOffset, -0.03, 0.03);
    
    // Apply deformation
    float3 deformedPosition = baseDirection * (uniforms.baseRadius + totalOffset);
    
    // Transform to clip space
    float4 clipPosition = uniforms.modelViewProjectionMatrix * float4(deformedPosition, 1.0);
    
    // Compute normal (for sphere: normal = normalized position)
    float3 normal = normalize(deformedPosition);
    
    VertexOut out;
    out.position = clipPosition;
    out.worldPosition = deformedPosition;
    out.normal = normal;
    
    return out;
}

// MARK: - Fragment Shader

fragment float4 fragment_main(
    VertexOut in [[stage_in]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    // Debug: Wireframe mode
    if (uniforms.debugWireframe) {
        return float4(0.0, 1.0, 0.0, 1.0); // Green wireframe
    }
    
    // Debug: Normal visualization
    if (uniforms.debugNormals) {
        return float4(in.normal * 0.5 + 0.5, 1.0);
    }
    
    // Material properties
    float3 albedo = uniforms.orbColor; // #E6E7E9 (bone/off-white)
    float3 lightDir = normalize(uniforms.lightDirection);
    float3 viewDir = normalize(uniforms.cameraPosition - in.worldPosition);
    float3 normal = normalize(in.normal);
    
    // Diffuse (Lambert) - slightly tighter falloff
    float diffuse = max(dot(normal, lightDir), 0.0);
    diffuse = pow(diffuse, 1.5);
    
    // Specular (Blinn-Phong) - subtle
    float3 halfVector = normalize(lightDir + viewDir);
    float specular = pow(max(dot(normal, halfVector), 0.0), 8.0);
    specular *= 0.15; // Low intensity (no harsh highlights)
    
    // Ambient (soft base illumination)
    float ambient = 0.2;
    
    // Combine lighting
    float3 color = albedo * (ambient + diffuse * 0.6) + float3(specular);
    
    return float4(color, 1.0);
}

// MARK: - Simple Shader for Fallback

// Fallback vertex shader (no deformation)
vertex VertexOut vertex_simple(
    VertexIn in [[stage_in]],
    constant Uniforms& uniforms [[buffer(1)]]
) {
    float3 position = normalize(in.position) * uniforms.baseRadius;
    float4 clipPosition = uniforms.modelViewProjectionMatrix * float4(position, 1.0);
    
    VertexOut out;
    out.position = clipPosition;
    out.worldPosition = position;
    out.normal = normalize(position);
    
    return out;
}

// Solid color fragment shader (fallback for errors)
fragment float4 fragment_solid(
    VertexOut in [[stage_in]],
    constant Uniforms& uniforms [[buffer(0)]]
) {
    return float4(uniforms.orbColor, 1.0);
}
