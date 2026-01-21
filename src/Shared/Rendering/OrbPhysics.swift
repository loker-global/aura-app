// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// OrbPhysics.swift — Mass-spring-damper physics simulation

import Foundation
import simd

// MARK: - Physics Constants (from PHYSICS-SPEC.md)

/// Physics constants for the orb simulation.
/// All values are tuned per PHYSICS-SPEC.md for "presence over reactivity".
public struct OrbPhysicsConstants {
    // Geometry
    public static let baseRadius: Float = 1.0           // Unit sphere
    public static let vertexCount: Int = 2562           // Icosphere subdivision 5
    public static let mass: Float = 1.0                 // kg (unit mass)
    
    // Springs
    public static let springConstant: Float = 10.0      // N/m (base tension)
    public static let springDamping: Float = 0.85       // Dimensionless
    public static let maxDeformation: Float = 0.03      // 3% max radius
    
    // Damping
    public static let globalDamping: Float = 0.75       // Energy dissipation
    
    // Forces (from audio features)
    public static let radialForceScale: Float = 0.03    // 3% max expansion
    public static let impulseForceScale: Float = 0.5    // N·s
    public static let impulseDuration: Float = 0.15     // seconds
    public static let tensionBase: Float = 10.0         // N/m
    public static let tensionRange: Float = 5.0         // Modulation ±50%
    public static let rippleAmplitude: Float = 0.005    // 0.5% local
    public static let rippleFrequency: Float = 8.0      // Hz
    
    // Constraints
    public static let maxVelocity: Float = 0.5          // m/s (50% radius/s)
    
    // Silence behavior
    public static let silenceDecayTime: Float = 2.0     // seconds
    public static let ambientFrequency: Float = 0.05    // Hz (very slow)
    public static let ambientAmplitude: Float = 0.001   // 0.1% drift
    
    // Simulation
    public static let updateRate: Float = 60.0          // Hz
    public static let deltaTime: Float = 1.0 / 60.0     // Fixed timestep
}

// MARK: - OrbVertex

/// Represents a vertex on the orb surface with physics properties.
public struct OrbVertex {
    /// Base position (normalized direction from center)
    public var basePosition: SIMD3<Float>
    
    /// Current position
    public var position: SIMD3<Float>
    
    /// Current velocity
    public var velocity: SIMD3<Float>
    
    /// Distance from center
    public var distance: Float {
        simd_length(position)
    }
    
    public init(basePosition: SIMD3<Float>) {
        self.basePosition = simd_normalize(basePosition)
        self.position = basePosition * OrbPhysicsConstants.baseRadius
        self.velocity = .zero
    }
}

// MARK: - OrbPhysics

/// Physics simulation for the orb using mass-spring-damper model.
/// Per ARCHITECTURE.md: Pure Swift, no rendering dependency.
/// Updates at fixed 60Hz timestep for deterministic replay.
///
/// Thread Safety: All methods should be called from the physics thread.
public final class OrbPhysics {
    
    // MARK: - Properties
    
    /// Orb vertices (icosphere mesh)
    public private(set) var vertices: [OrbVertex]
    
    /// Base radius of the orb
    public let baseRadius: Float = OrbPhysicsConstants.baseRadius
    
    /// Current radial expansion (0.0 - maxDeformation)
    public private(set) var radialExpansion: Float = 0
    
    /// Current ripple amplitude
    public private(set) var currentRippleAmplitude: Float = 0
    
    /// Current surface tension (spring constant)
    public private(set) var surfaceTension: Float = OrbPhysicsConstants.tensionBase
    
    /// Simulation time (for noise functions)
    public private(set) var time: Float = 0
    
    /// Time since last audio input (for silence handling)
    public private(set) var silenceTime: Float = 0
    
    /// Whether the orb is in silence state
    public var isSilent: Bool {
        silenceTime > 0
    }
    
    /// Whether the orb is in deep silence (>2 seconds)
    public var isDeepSilence: Bool {
        silenceTime > OrbPhysicsConstants.silenceDecayTime
    }
    
    // MARK: - Private Properties
    
    // Active impulse tracking
    private var activeImpulse: (magnitude: Float, direction: SIMD3<Float>, remainingTime: Float)?
    
    // Exponential decay for ripples during silence
    private var rippleDecayFactor: Float = 1.0
    
    // Constants cache
    private let c = OrbPhysicsConstants.self
    
    // MARK: - Initialization
    
    public init() {
        // Generate icosphere vertices
        vertices = Self.generateIcosphereVertices()
    }
    
    // MARK: - Force Application
    
    /// Applies forces from audio features.
    /// - Parameters:
    ///   - radialForce: RMS-based radial expansion force (0.0 - 1.0 normalized)
    ///   - tension: Spectral centroid-based surface tension modifier
    ///   - rippleAmplitude: ZCR-based micro-ripple amplitude (0.0 - 1.0 normalized)
    ///   - impulse: Onset-based impulse force (0.0 - 1.0 normalized)
    ///   - isSilent: Whether audio is silent
    public func applyForces(
        radialForce: Float,
        tension: Float,
        rippleAmplitude: Float,
        impulse: Float,
        isSilent: Bool
    ) {
        // Handle silence tracking
        if isSilent {
            silenceTime += c.deltaTime
        } else {
            silenceTime = 0
            rippleDecayFactor = 1.0
        }
        
        // Apply radial force (clamped to max deformation)
        let targetExpansion = radialForce * c.radialForceScale * baseRadius
        radialExpansion = lerp(
            from: radialExpansion,
            to: targetExpansion,
            t: isSilent ? 0.1 : 0.3 // Slower return during silence
        )
        
        // Apply surface tension (from spectral centroid)
        surfaceTension = tension
        
        // Apply ripple amplitude (with decay during silence)
        if isSilent {
            // Exponential decay during silence (τ = 1.5s)
            rippleDecayFactor *= exp(-c.deltaTime / 1.5)
        }
        currentRippleAmplitude = rippleAmplitude * c.rippleAmplitude * rippleDecayFactor
        
        // Apply impulse if detected
        if impulse > 0 {
            let direction = randomRadialDirection()
            activeImpulse = (
                magnitude: impulse * c.impulseForceScale,
                direction: direction,
                remainingTime: c.impulseDuration
            )
        }
    }
    
    // MARK: - Physics Update
    
    /// Updates the physics simulation by one timestep.
    /// Per PHYSICS-SPEC.md: Uses Velocity Verlet integration at 60Hz.
    public func update() {
        let dt = c.deltaTime
        time += dt
        
        // Process active impulse
        var impulseForce: SIMD3<Float> = .zero
        if var impulse = activeImpulse {
            impulse.remainingTime -= dt
            if impulse.remainingTime > 0 {
                impulseForce = impulse.direction * impulse.magnitude
                activeImpulse = impulse
            } else {
                activeImpulse = nil
            }
        }
        
        // Update each vertex
        for i in 0..<vertices.count {
            updateVertex(at: i, impulseForce: impulseForce, dt: dt)
        }
    }
    
    /// Updates a single vertex using spring-damper physics.
    private func updateVertex(at index: Int, impulseForce: SIMD3<Float>, dt: Float) {
        var vertex = vertices[index]
        
        // Calculate target radius (base + expansion + ripple)
        let rippleOffset = calculateRippleOffset(at: vertex.basePosition)
        let targetRadius = baseRadius + radialExpansion + rippleOffset
        
        // Calculate spring force (toward target radius)
        let currentRadius = simd_length(vertex.position)
        let displacement = currentRadius - targetRadius
        let clampedDisplacement = clamp(displacement, -c.maxDeformation, c.maxDeformation)
        
        let springForce = -surfaceTension * clampedDisplacement
        let direction = simd_normalize(vertex.position)
        
        // Calculate damping force
        let radialVelocity = simd_dot(vertex.velocity, direction)
        let dampingForce = -c.springDamping * radialVelocity
        
        // Total force
        let totalRadialForce = springForce + dampingForce
        var totalForce = direction * totalRadialForce
        
        // Add impulse force (if any)
        totalForce += impulseForce * simd_dot(direction, impulseForce)
        
        // Velocity Verlet integration
        let acceleration = totalForce / c.mass
        
        // Update position
        vertex.position += vertex.velocity * dt + 0.5 * acceleration * dt * dt
        
        // Update velocity with global damping
        vertex.velocity += acceleration * dt
        vertex.velocity *= (1.0 - c.globalDamping * dt)
        
        // Clamp velocity
        let speed = simd_length(vertex.velocity)
        if speed > c.maxVelocity {
            vertex.velocity = simd_normalize(vertex.velocity) * c.maxVelocity
        }
        
        // Enforce deformation constraints
        let newRadius = simd_length(vertex.position)
        let minRadius = baseRadius * (1.0 - c.maxDeformation)
        let maxRadius = baseRadius * (1.0 + c.maxDeformation)
        
        if newRadius > maxRadius {
            vertex.position = simd_normalize(vertex.position) * maxRadius
        } else if newRadius < minRadius {
            vertex.position = simd_normalize(vertex.position) * minRadius
        }
        
        vertices[index] = vertex
    }
    
    /// Calculates ripple offset at a position using simplex noise.
    private func calculateRippleOffset(at position: SIMD3<Float>) -> Float {
        guard currentRippleAmplitude > 0.0001 else { return 0 }
        
        // Use simplex noise for spatial variation
        let noise = simplexNoise3D(
            position * 5.0 + SIMD3<Float>(time * c.rippleFrequency, 0, 0)
        )
        
        // Add ambient motion during deep silence
        var offset = noise * currentRippleAmplitude
        
        if isDeepSilence {
            // Very slow ambient drift
            let ambient = sin(time * c.ambientFrequency * 2 * .pi)
            offset += ambient * c.ambientAmplitude * baseRadius
        }
        
        return offset
    }
    
    // MARK: - Reset
    
    /// Resets the physics to initial state.
    public func reset() {
        vertices = Self.generateIcosphereVertices()
        radialExpansion = 0
        currentRippleAmplitude = 0
        surfaceTension = c.tensionBase
        time = 0
        silenceTime = 0
        rippleDecayFactor = 1.0
        activeImpulse = nil
    }
    
    // MARK: - Helpers
    
    private func randomRadialDirection() -> SIMD3<Float> {
        // Generate random point on unit sphere
        let theta = Float.random(in: 0...(2 * .pi))
        let phi = acos(Float.random(in: -1...1))
        
        return SIMD3<Float>(
            sin(phi) * cos(theta),
            sin(phi) * sin(theta),
            cos(phi)
        )
    }
    
    private func lerp(from: Float, to: Float, t: Float) -> Float {
        return from + (to - from) * t
    }
    
    private func clamp(_ value: Float, _ minVal: Float, _ maxVal: Float) -> Float {
        return max(minVal, min(maxVal, value))
    }
    
    // MARK: - Icosphere Generation
    
    /// Generates icosphere vertices with subdivision level 5.
    /// Returns 2562 vertices uniformly distributed on a sphere.
    private static func generateIcosphereVertices() -> [OrbVertex] {
        // Golden ratio for icosahedron
        let phi = (1.0 + sqrt(5.0)) / 2.0
        let phiF = Float(phi)
        
        // Base icosahedron vertices (12)
        var positions: [SIMD3<Float>] = [
            SIMD3<Float>(-1, phiF, 0),
            SIMD3<Float>(1, phiF, 0),
            SIMD3<Float>(-1, -phiF, 0),
            SIMD3<Float>(1, -phiF, 0),
            SIMD3<Float>(0, -1, phiF),
            SIMD3<Float>(0, 1, phiF),
            SIMD3<Float>(0, -1, -phiF),
            SIMD3<Float>(0, 1, -phiF),
            SIMD3<Float>(phiF, 0, -1),
            SIMD3<Float>(phiF, 0, 1),
            SIMD3<Float>(-phiF, 0, -1),
            SIMD3<Float>(-phiF, 0, 1)
        ]
        
        // Normalize to unit sphere
        positions = positions.map { simd_normalize($0) }
        
        // Base icosahedron faces (20 triangles)
        var faces: [(Int, Int, Int)] = [
            (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
            (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
            (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
            (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)
        ]
        
        // Subdivide 5 times to get ~2562 vertices
        for _ in 0..<5 {
            var newFaces: [(Int, Int, Int)] = []
            var midpointCache: [String: Int] = [:]
            
            for (i0, i1, i2) in faces {
                // Get midpoints
                let a = getMidpoint(i0, i1, positions: &positions, cache: &midpointCache)
                let b = getMidpoint(i1, i2, positions: &positions, cache: &midpointCache)
                let c = getMidpoint(i2, i0, positions: &positions, cache: &midpointCache)
                
                // Create 4 new faces
                newFaces.append((i0, a, c))
                newFaces.append((i1, b, a))
                newFaces.append((i2, c, b))
                newFaces.append((a, b, c))
            }
            
            faces = newFaces
        }
        
        // Convert to OrbVertices
        return positions.map { OrbVertex(basePosition: $0) }
    }
    
    private static func getMidpoint(
        _ i0: Int,
        _ i1: Int,
        positions: inout [SIMD3<Float>],
        cache: inout [String: Int]
    ) -> Int {
        // Create unique key for edge
        let key = i0 < i1 ? "\(i0)-\(i1)" : "\(i1)-\(i0)"
        
        // Check cache
        if let index = cache[key] {
            return index
        }
        
        // Calculate midpoint and normalize to sphere
        let midpoint = simd_normalize((positions[i0] + positions[i1]) / 2.0)
        
        // Add to positions
        let index = positions.count
        positions.append(midpoint)
        cache[key] = index
        
        return index
    }
    
    // MARK: - Simplex Noise
    
    /// 3D Simplex noise implementation (Stefan Gustavson's algorithm).
    private func simplexNoise3D(_ v: SIMD3<Float>) -> Float {
        // Skew and unskew factors
        let F3: Float = 1.0 / 3.0
        let G3: Float = 1.0 / 6.0
        
        // Skew input space
        let s = (v.x + v.y + v.z) * F3
        let i = floor(v.x + s)
        let j = floor(v.y + s)
        let k = floor(v.z + s)
        
        // Unskew cell origin
        let t = (i + j + k) * G3
        let x0 = v.x - i + t
        let y0 = v.y - j + t
        let z0 = v.z - k + t
        
        // Determine simplex
        var i1, j1, k1: Float
        var i2, j2, k2: Float
        
        if x0 >= y0 {
            if y0 >= z0 {
                i1 = 1; j1 = 0; k1 = 0; i2 = 1; j2 = 1; k2 = 0
            } else if x0 >= z0 {
                i1 = 1; j1 = 0; k1 = 0; i2 = 1; j2 = 0; k2 = 1
            } else {
                i1 = 0; j1 = 0; k1 = 1; i2 = 1; j2 = 0; k2 = 1
            }
        } else {
            if y0 < z0 {
                i1 = 0; j1 = 0; k1 = 1; i2 = 0; j2 = 1; k2 = 1
            } else if x0 < z0 {
                i1 = 0; j1 = 1; k1 = 0; i2 = 0; j2 = 1; k2 = 1
            } else {
                i1 = 0; j1 = 1; k1 = 0; i2 = 1; j2 = 1; k2 = 0
            }
        }
        
        // Offsets for corners
        let x1 = x0 - i1 + G3
        let y1 = y0 - j1 + G3
        let z1 = z0 - k1 + G3
        let x2 = x0 - i2 + 2.0 * G3
        let y2 = y0 - j2 + 2.0 * G3
        let z2 = z0 - k2 + 2.0 * G3
        let x3 = x0 - 1.0 + 3.0 * G3
        let y3 = y0 - 1.0 + 3.0 * G3
        let z3 = z0 - 1.0 + 3.0 * G3
        
        // Hash coordinates
        let ii = Int(i) & 255
        let jj = Int(j) & 255
        let kk = Int(k) & 255
        
        // Calculate contributions from corners
        var n0, n1, n2, n3: Float
        
        var t0 = 0.6 - x0*x0 - y0*y0 - z0*z0
        if t0 < 0 { n0 = 0 }
        else {
            t0 *= t0
            n0 = t0 * t0 * grad3(hash: perm[ii + perm[jj + perm[kk]]], x: x0, y: y0, z: z0)
        }
        
        var t1 = 0.6 - x1*x1 - y1*y1 - z1*z1
        if t1 < 0 { n1 = 0 }
        else {
            t1 *= t1
            n1 = t1 * t1 * grad3(hash: perm[ii + Int(i1) + perm[jj + Int(j1) + perm[kk + Int(k1)]]], x: x1, y: y1, z: z1)
        }
        
        var t2 = 0.6 - x2*x2 - y2*y2 - z2*z2
        if t2 < 0 { n2 = 0 }
        else {
            t2 *= t2
            n2 = t2 * t2 * grad3(hash: perm[ii + Int(i2) + perm[jj + Int(j2) + perm[kk + Int(k2)]]], x: x2, y: y2, z: z2)
        }
        
        var t3 = 0.6 - x3*x3 - y3*y3 - z3*z3
        if t3 < 0 { n3 = 0 }
        else {
            t3 *= t3
            n3 = t3 * t3 * grad3(hash: perm[ii + 1 + perm[jj + 1 + perm[kk + 1]]], x: x3, y: y3, z: z3)
        }
        
        // Scale to [-1, 1]
        return 32.0 * (n0 + n1 + n2 + n3)
    }
    
    private func grad3(hash: Int, x: Float, y: Float, z: Float) -> Float {
        let h = hash & 15
        let u = h < 8 ? x : y
        let v = h < 4 ? y : (h == 12 || h == 14 ? x : z)
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v)
    }
    
    // Permutation table for noise
    private let perm: [Int] = {
        let p: [Int] = [151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,
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
                       222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180]
        return p + p // Double for easy wrapping
    }()
}

// MARK: - OrbPhysics Data Export

extension OrbPhysics {
    
    /// Returns vertex positions as a flat array for rendering.
    /// Format: [x0, y0, z0, x1, y1, z1, ...]
    public var vertexPositions: [Float] {
        var positions: [Float] = []
        positions.reserveCapacity(vertices.count * 3)
        
        for vertex in vertices {
            positions.append(vertex.position.x)
            positions.append(vertex.position.y)
            positions.append(vertex.position.z)
        }
        
        return positions
    }
    
    /// Returns vertex normals as a flat array for rendering.
    /// For a sphere, normal = normalized position.
    public var vertexNormals: [Float] {
        var normals: [Float] = []
        normals.reserveCapacity(vertices.count * 3)
        
        for vertex in vertices {
            let normal = simd_normalize(vertex.position)
            normals.append(normal.x)
            normals.append(normal.y)
            normals.append(normal.z)
        }
        
        return normals
    }
    
    /// Returns current state for shader uniforms.
    public var shaderState: OrbShaderState {
        OrbShaderState(
            baseRadius: baseRadius,
            radialExpansion: radialExpansion,
            rippleAmplitude: currentRippleAmplitude,
            time: time
        )
    }
}

/// State data for orb shaders.
public struct OrbShaderState {
    public let baseRadius: Float
    public let radialExpansion: Float
    public let rippleAmplitude: Float
    public let time: Float
}
