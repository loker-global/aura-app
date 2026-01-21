// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// Tests/PhysicsTests/OrbPhysicsTests.swift

import XCTest
import simd
@testable import AURA

final class OrbPhysicsTests: XCTestCase {
    
    var physics: OrbPhysics!
    
    override func setUp() {
        super.setUp()
        physics = OrbPhysics()
    }
    
    override func tearDown() {
        physics = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialVertexCount() {
        // Per PHYSICS-SPEC.md: 2562 vertices for icosphere subdivision 5
        XCTAssertEqual(physics.vertices.count, 2562)
    }
    
    func testInitialRadius() {
        // Per PHYSICS-SPEC.md: Base radius is 1.0
        XCTAssertEqual(physics.baseRadius, 1.0)
    }
    
    func testInitialVerticesOnSurface() {
        // All vertices should be at base radius
        for vertex in physics.vertices {
            let distance = simd_length(vertex.position)
            XCTAssertEqual(distance, physics.baseRadius, accuracy: 0.01)
        }
    }
    
    // MARK: - Silence Tests
    
    func testSilenceReturnsToRest() {
        // Per TESTING-SCENARIOS.md: Silence returns to rest
        
        // Given: Apply some force first
        physics.applyForces(
            radialForce: 0.5,
            tension: 12.0,
            rippleAmplitude: 0.3,
            impulse: 0.2,
            isSilent: false
        )
        
        // Run a few frames
        for _ in 0..<30 {
            physics.update()
        }
        
        // When: Apply silence for 3 seconds (180 frames @ 60Hz)
        for _ in 0..<180 {
            physics.applyForces(
                radialForce: 0.0,
                tension: 10.0,
                rippleAmplitude: 0.0,
                impulse: 0.0,
                isSilent: true
            )
            physics.update()
        }
        
        // Then: All vertices should be near base radius (±1%)
        for vertex in physics.vertices {
            let distance = simd_length(vertex.position)
            XCTAssertEqual(distance, physics.baseRadius, accuracy: 0.01)
        }
    }
    
    // MARK: - Deformation Clamp Tests
    
    func testMaxDeformationClamp() {
        // Per PHYSICS-SPEC.md: Max deformation is 3%
        
        // Given: Apply maximum force
        physics.applyForces(
            radialForce: 10.0, // Extreme value
            tension: 10.0,
            rippleAmplitude: 10.0, // Extreme value
            impulse: 1.0,
            isSilent: false
        )
        
        // When: Update physics
        physics.update()
        
        // Then: Deformation should be clamped to ±3%
        let maxRadius = physics.baseRadius * 1.03
        let minRadius = physics.baseRadius * 0.97
        
        for vertex in physics.vertices {
            let distance = simd_length(vertex.position)
            XCTAssertLessThanOrEqual(distance, maxRadius)
            XCTAssertGreaterThanOrEqual(distance, minRadius)
        }
    }
    
    // MARK: - Determinism Tests
    
    func testDeterminism() {
        // Per TESTING-SCENARIOS.md: Same input → Same output
        
        let physics1 = OrbPhysics()
        let physics2 = OrbPhysics()
        
        // Given: Same sequence of forces
        let forces: [(Float, Float, Float, Float)] = [
            (0.3, 12.0, 0.1, 0.0),
            (0.5, 14.0, 0.2, 0.3),
            (0.2, 11.0, 0.05, 0.0),
            (0.0, 10.0, 0.0, 0.0),
        ]
        
        // When: Apply same forces to both
        for (radial, tension, ripple, impulse) in forces {
            physics1.applyForces(
                radialForce: radial,
                tension: tension,
                rippleAmplitude: ripple,
                impulse: impulse,
                isSilent: radial < 0.01
            )
            physics2.applyForces(
                radialForce: radial,
                tension: tension,
                rippleAmplitude: ripple,
                impulse: impulse,
                isSilent: radial < 0.01
            )
            
            physics1.update()
            physics2.update()
        }
        
        // Then: Vertex positions should match exactly
        for (v1, v2) in zip(physics1.vertices, physics2.vertices) {
            XCTAssertEqual(v1.position.x, v2.position.x, accuracy: 0.0001)
            XCTAssertEqual(v1.position.y, v2.position.y, accuracy: 0.0001)
            XCTAssertEqual(v1.position.z, v2.position.z, accuracy: 0.0001)
        }
    }
    
    // MARK: - Impulse Tests
    
    func testImpulseDecay() {
        // Per TESTING-SCENARIOS.md: Impulse decays to rest
        
        // Given: Apply strong impulse
        physics.applyForces(
            radialForce: 0.0,
            tension: 10.0,
            rippleAmplitude: 0.0,
            impulse: 1.0, // Maximum impulse
            isSilent: true
        )
        
        // Calculate initial "energy" (sum of velocity magnitudes)
        var initialEnergy: Float = 0
        for _ in 0..<10 {
            physics.update()
        }
        for vertex in physics.vertices {
            initialEnergy += simd_length(vertex.velocity)
        }
        
        // When: Run for 2 seconds (120 frames) with no new impulses
        for _ in 0..<120 {
            physics.applyForces(
                radialForce: 0.0,
                tension: 10.0,
                rippleAmplitude: 0.0,
                impulse: 0.0,
                isSilent: true
            )
            physics.update()
        }
        
        // Then: Energy should have decayed significantly (>95%)
        var finalEnergy: Float = 0
        for vertex in physics.vertices {
            finalEnergy += simd_length(vertex.velocity)
        }
        
        XCTAssertLessThan(finalEnergy, initialEnergy * 0.05)
    }
    
    // MARK: - Radial Expansion Tests
    
    func testRadialExpansion() {
        // Given: Apply radial force
        physics.applyForces(
            radialForce: 0.5,
            tension: 10.0,
            rippleAmplitude: 0.0,
            impulse: 0.0,
            isSilent: false
        )
        
        // Run several frames to let physics settle
        for _ in 0..<30 {
            physics.update()
        }
        
        // Then: Average radius should have increased
        var totalRadius: Float = 0
        for vertex in physics.vertices {
            totalRadius += simd_length(vertex.position)
        }
        let avgRadius = totalRadius / Float(physics.vertices.count)
        
        XCTAssertGreaterThan(avgRadius, physics.baseRadius)
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        // Given: Some physics simulation run
        physics.applyForces(
            radialForce: 0.5,
            tension: 15.0,
            rippleAmplitude: 0.3,
            impulse: 0.5,
            isSilent: false
        )
        
        for _ in 0..<60 {
            physics.update()
        }
        
        // When: Reset
        physics.reset()
        
        // Then: Should be back to initial state
        XCTAssertEqual(physics.time, 0)
        XCTAssertEqual(physics.radialExpansion, 0)
        XCTAssertEqual(physics.currentRippleAmplitude, 0)
        
        for vertex in physics.vertices {
            let distance = simd_length(vertex.position)
            XCTAssertEqual(distance, physics.baseRadius, accuracy: 0.001)
            XCTAssertEqual(simd_length(vertex.velocity), 0, accuracy: 0.001)
        }
    }
    
    // MARK: - Silence Tracking Tests
    
    func testSilenceTracking() {
        // Given: Start with non-silent audio
        physics.applyForces(
            radialForce: 0.5,
            tension: 10.0,
            rippleAmplitude: 0.2,
            impulse: 0.0,
            isSilent: false
        )
        physics.update()
        
        XCTAssertFalse(physics.isSilent)
        
        // When: Switch to silence for several frames
        for _ in 0..<10 {
            physics.applyForces(
                radialForce: 0.0,
                tension: 10.0,
                rippleAmplitude: 0.0,
                impulse: 0.0,
                isSilent: true
            )
            physics.update()
        }
        
        // Then: Should be in silence state
        XCTAssertTrue(physics.isSilent)
    }
    
    func testDeepSilence() {
        // Given: Silence for >2 seconds (per PHYSICS-SPEC.md)
        for _ in 0..<150 { // 2.5 seconds at 60Hz
            physics.applyForces(
                radialForce: 0.0,
                tension: 10.0,
                rippleAmplitude: 0.0,
                impulse: 0.0,
                isSilent: true
            )
            physics.update()
        }
        
        // Then: Should be in deep silence
        XCTAssertTrue(physics.isDeepSilence)
    }
    
    // MARK: - Vertex Data Export Tests
    
    func testVertexPositionsExport() {
        let positions = physics.vertexPositions
        
        // Should have 3 floats per vertex (x, y, z)
        XCTAssertEqual(positions.count, physics.vertices.count * 3)
    }
    
    func testVertexNormalsExport() {
        let normals = physics.vertexNormals
        
        // Should have 3 floats per vertex (x, y, z)
        XCTAssertEqual(normals.count, physics.vertices.count * 3)
        
        // Normals should be normalized (length ≈ 1)
        for i in stride(from: 0, to: normals.count, by: 3) {
            let length = sqrt(normals[i]*normals[i] + normals[i+1]*normals[i+1] + normals[i+2]*normals[i+2])
            XCTAssertEqual(length, 1.0, accuracy: 0.01)
        }
    }
    
    func testShaderState() {
        physics.applyForces(
            radialForce: 0.5,
            tension: 12.0,
            rippleAmplitude: 0.3,
            impulse: 0.0,
            isSilent: false
        )
        physics.update()
        
        let state = physics.shaderState
        
        XCTAssertEqual(state.baseRadius, physics.baseRadius)
        XCTAssertGreaterThan(state.radialExpansion, 0)
        XCTAssertGreaterThan(state.time, 0)
    }
}
