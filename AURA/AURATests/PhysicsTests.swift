import XCTest
@testable import AURA

final class PhysicsTests: XCTestCase {
    
    func testOrbPhysicsInitialization() {
        let physics = OrbPhysics()
        
        // Check initial state
        XCTAssertEqual(physics.baseRadius, 1.0)
        XCTAssertEqual(physics.radialExpansion, 0.0)
        XCTAssertEqual(physics.maxDeformation, 0.03)
    }
    
    func testSilenceReturnsToRest() {
        let physics = OrbPhysics()
        
        // Apply some force
        let analysis = AudioAnalysis(
            rms: 0.5,
            spectralCentroid: 0.5,
            zeroCrossingRate: 0.3,
            onsetDetected: false,
            onsetMagnitude: 0
        )
        physics.applyAudioAnalysis(analysis)
        
        // Update several times
        for _ in 0..<60 {
            physics.update()
        }
        
        // Now apply silence
        let silence = AudioAnalysis(
            rms: 0.0,
            spectralCentroid: 0.0,
            zeroCrossingRate: 0.0,
            onsetDetected: false,
            onsetMagnitude: 0
        )
        
        // Update for 2 seconds (120 frames at 60Hz)
        for _ in 0..<120 {
            physics.applyAudioAnalysis(silence)
            physics.update()
        }
        
        // Should be near rest (within small tolerance)
        XCTAssertLessThan(abs(physics.radialExpansion), 0.005)
    }
    
    func testImpulseDecay() {
        let physics = OrbPhysics()
        
        // Apply impulse
        let impulse = AudioAnalysis(
            rms: 0.8,
            spectralCentroid: 0.5,
            zeroCrossingRate: 0.3,
            onsetDetected: true,
            onsetMagnitude: 1.0
        )
        physics.applyAudioAnalysis(impulse)
        physics.update()
        
        let initialExpansion = physics.radialExpansion
        
        // Apply silence and update for 2 seconds
        let silence = AudioAnalysis(
            rms: 0.0,
            spectralCentroid: 0.0,
            zeroCrossingRate: 0.0,
            onsetDetected: false,
            onsetMagnitude: 0
        )
        
        for _ in 0..<120 {
            physics.applyAudioAnalysis(silence)
            physics.update()
        }
        
        // Should decay to near rest
        XCTAssertLessThan(abs(physics.radialExpansion), abs(initialExpansion) * 0.1)
    }
    
    func testDeformationClamping() {
        let physics = OrbPhysics()
        
        // Apply very loud signal (beyond normal range)
        for _ in 0..<60 {
            let loud = AudioAnalysis(
                rms: 1.0,
                spectralCentroid: 1.0,
                zeroCrossingRate: 1.0,
                onsetDetected: true,
                onsetMagnitude: 1.0
            )
            physics.applyAudioAnalysis(loud)
            physics.update()
        }
        
        // Deformation should be clamped to 3%
        XCTAssertLessThanOrEqual(abs(physics.radialExpansion), 0.03)
    }
    
    func testDeterminism() {
        let physics1 = OrbPhysics()
        let physics2 = OrbPhysics()
        
        // Apply same sequence to both
        let analyses = [
            AudioAnalysis(rms: 0.3, spectralCentroid: 0.5, zeroCrossingRate: 0.2, onsetDetected: false, onsetMagnitude: 0),
            AudioAnalysis(rms: 0.6, spectralCentroid: 0.4, zeroCrossingRate: 0.3, onsetDetected: true, onsetMagnitude: 0.8),
            AudioAnalysis(rms: 0.4, spectralCentroid: 0.6, zeroCrossingRate: 0.25, onsetDetected: false, onsetMagnitude: 0),
            AudioAnalysis(rms: 0.1, spectralCentroid: 0.3, zeroCrossingRate: 0.1, onsetDetected: false, onsetMagnitude: 0)
        ]
        
        for analysis in analyses {
            physics1.applyAudioAnalysis(analysis)
            physics1.update()
            
            physics2.applyAudioAnalysis(analysis)
            physics2.update()
        }
        
        // Both should produce identical results
        XCTAssertEqual(physics1.radialExpansion, physics2.radialExpansion, accuracy: 0.0001)
        XCTAssertEqual(physics1.rippleAmount, physics2.rippleAmount, accuracy: 0.0001)
    }
    
    func testOrbStateSnapshot() {
        let physics = OrbPhysics()
        
        let state = physics.currentState()
        
        XCTAssertEqual(state.radialExpansion, physics.radialExpansion)
        XCTAssertEqual(state.rippleAmount, physics.rippleAmount)
        XCTAssertEqual(state.surfaceTension, physics.surfaceTension)
        XCTAssertEqual(state.time, physics.time)
    }
    
    func testPhysicsReset() {
        let physics = OrbPhysics()
        
        // Apply some forces
        let analysis = AudioAnalysis(
            rms: 0.7,
            spectralCentroid: 0.5,
            zeroCrossingRate: 0.3,
            onsetDetected: true,
            onsetMagnitude: 0.9
        )
        physics.applyAudioAnalysis(analysis)
        
        for _ in 0..<30 {
            physics.update()
        }
        
        // Reset
        physics.reset()
        
        // Should be at initial state
        XCTAssertEqual(physics.radialExpansion, 0.0)
        XCTAssertEqual(physics.time, 0.0)
    }
}
