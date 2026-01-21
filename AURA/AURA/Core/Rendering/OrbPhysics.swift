import Foundation
import simd

/// Orb physics simulation (mass-spring-damper system)
/// Audio features → force application
/// Updates at fixed timestep (60Hz)
/// Pure Swift, no rendering dependency
final class OrbPhysics {
    
    // MARK: - Constants (from PHYSICS-SPEC.md)
    
    // Geometry
    let baseRadius: Float = 1.0
    let vertexCount: Int = 2562  // Icosphere subdivision 5
    let mass: Float = 1.0
    
    // Springs
    let springConstant: Float = 10.0
    let springDamping: Float = 0.85
    let maxDeformation: Float = 0.03  // 3% maximum
    
    // Damping
    let globalDamping: Float = 0.75
    
    // Forces
    let radialForceScale: Float = 0.03
    let impulseForceScale: Float = 0.5
    let tensionBase: Float = 10.0
    let tensionRange: Float = 5.0
    let rippleAmplitude: Float = 0.005
    let rippleFrequency: Float = 8.0
    
    // Constraints
    let maxVelocity: Float = 0.5
    
    // Silence
    let silenceDecayTime: Float = 2.0
    let ambientFrequency: Float = 0.05
    let ambientAmplitude: Float = 0.001
    
    // Simulation
    let updateRate: Float = 60.0
    let deltaTime: Float
    
    // MARK: - State
    
    private(set) var radialExpansion: Float = 0
    private(set) var radialVelocity: Float = 0
    private(set) var rippleAmount: Float = 0
    private(set) var surfaceTension: Float = 10.0
    private(set) var time: Float = 0
    
    // Active forces
    private var targetRadialForce: Float = 0
    private var impulseForce: Float = 0
    private var impulseDuration: Float = 0
    private var silenceTime: Float = 0
    
    // Silence threshold
    private let silenceThreshold: Float = 0.02
    
    // MARK: - Initialization
    
    init() {
        deltaTime = 1.0 / updateRate
    }
    
    // MARK: - Force Application (from Audio Analysis)
    
    /// Apply audio analysis to physics
    func applyAudioAnalysis(_ analysis: AudioAnalysis) {
        // Radial force from RMS
        targetRadialForce = analysis.rms * radialForceScale * baseRadius
        
        // Surface tension from spectral centroid
        surfaceTension = tensionBase + (analysis.spectralCentroid * tensionRange)
        
        // Ripple from ZCR
        rippleAmount = analysis.zeroCrossingRate * rippleAmplitude
        
        // Impulse from onset
        if analysis.onsetDetected {
            impulseForce = analysis.onsetMagnitude * impulseForceScale
            impulseDuration = 0.15
        }
        
        // Track silence
        if analysis.rms < silenceThreshold {
            silenceTime += deltaTime
        } else {
            silenceTime = 0
        }
    }
    
    // MARK: - Physics Update
    
    /// Update physics simulation (call at 60Hz)
    func update() {
        time += deltaTime
        
        // Calculate spring force
        let displacement = radialExpansion
        let springForce = -surfaceTension * displacement
        
        // Calculate damping force
        let dampingForce = -springDamping * radialVelocity
        
        // Calculate radial force from audio
        let audioForce = targetRadialForce
        
        // Calculate impulse force (decaying)
        var currentImpulse: Float = 0
        if impulseDuration > 0 {
            currentImpulse = impulseForce * (impulseDuration / 0.15)
            impulseDuration -= deltaTime
            if impulseDuration <= 0 {
                impulseDuration = 0
                impulseForce = 0
            }
        }
        
        // Total force
        let totalForce = springForce + dampingForce + audioForce + currentImpulse
        
        // Calculate acceleration
        let acceleration = totalForce / mass
        
        // Velocity Verlet integration
        radialExpansion += radialVelocity * deltaTime + 0.5 * acceleration * deltaTime * deltaTime
        
        // Update velocity
        radialVelocity += acceleration * deltaTime
        
        // Apply global damping
        radialVelocity *= (1.0 - globalDamping * deltaTime)
        
        // Clamp velocity
        if abs(radialVelocity) > maxVelocity {
            radialVelocity = sign(radialVelocity) * maxVelocity
        }
        
        // Clamp deformation
        radialExpansion = max(-maxDeformation, min(maxDeformation, radialExpansion))
        
        // Handle silence
        if silenceTime > silenceDecayTime {
            // Deep silence: ambient motion
            let ambientOffset = sin(time * ambientFrequency * 2 * .pi) * ambientAmplitude * baseRadius
            radialExpansion += ambientOffset * deltaTime
        } else if silenceTime > 0 {
            // Active silence: decay ripples
            let decayFactor = exp(-silenceTime / 1.5)
            rippleAmount *= decayFactor
        }
    }
    
    /// Get current orb state for rendering
    func currentState() -> OrbState {
        return OrbState(
            radialExpansion: radialExpansion,
            rippleAmount: rippleAmount,
            surfaceTension: surfaceTension,
            time: time
        )
    }
    
    /// Reset physics to initial state
    func reset() {
        radialExpansion = 0
        radialVelocity = 0
        rippleAmount = 0
        surfaceTension = tensionBase
        time = 0
        targetRadialForce = 0
        impulseForce = 0
        impulseDuration = 0
        silenceTime = 0
    }
}

// MARK: - Orb State

/// Immutable snapshot of orb state for rendering
struct OrbState {
    let radialExpansion: Float    // 0.0 to 0.03
    let rippleAmount: Float       // 0.0 to 0.005
    let surfaceTension: Float     // 10.0 to 15.0
    let time: Float               // For noise animation
}

// MARK: - Helper

private func sign(_ value: Float) -> Float {
    return value >= 0 ? 1.0 : -1.0
}
