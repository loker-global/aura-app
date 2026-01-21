// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// AudioFeatureExtractor.swift — Audio analysis for physics forces

import Foundation
import Accelerate

// MARK: - Audio Features

/// Audio features extracted from PCM buffers.
/// Maps to physics forces per AUDIO-MAPPING.md specification.
public struct AudioFeatures {
    /// RMS Energy (0.0 - 1.0): Overall loudness/energy
    /// Maps to: Orb radial force (expansion/contraction)
    public let rms: Float
    
    /// Spectral Centroid (0.0 - 1.0, normalized): Voice "brightness"
    /// Maps to: Orb surface tension (higher = tighter)
    public let spectralCentroid: Float
    
    /// Zero-Crossing Rate (0.0 - 1.0): Noisiness/fricatives
    /// Maps to: Orb surface micro-ripples
    public let zeroCrossingRate: Float
    
    /// Onset detected: Sudden energy increase (syllable attacks)
    /// Maps to: Impulse force (radial push)
    public let onsetDetected: Bool
    
    /// Onset magnitude (0.0 - 1.0) when onset is detected
    public let onsetMagnitude: Float
    
    /// Whether audio is considered silent
    public let isSilent: Bool
    
    public init(
        rms: Float,
        spectralCentroid: Float,
        zeroCrossingRate: Float,
        onsetDetected: Bool,
        onsetMagnitude: Float,
        isSilent: Bool
    ) {
        self.rms = rms
        self.spectralCentroid = spectralCentroid
        self.zeroCrossingRate = zeroCrossingRate
        self.onsetDetected = onsetDetected
        self.onsetMagnitude = onsetMagnitude
        self.isSilent = isSilent
    }
    
    /// Silent audio features (no voice present)
    public static var silent: AudioFeatures {
        AudioFeatures(
            rms: 0,
            spectralCentroid: 0.5,
            zeroCrossingRate: 0,
            onsetDetected: false,
            onsetMagnitude: 0,
            isSilent: true
        )
    }
}

// MARK: - AudioFeatureExtractor

/// Extracts audio features from PCM buffers for physics simulation.
/// Per AUDIO-MAPPING.md: RMS, Spectral Centroid, ZCR, Onset Detection.
///
/// Thread safety: All methods are thread-safe. Feature extraction runs on audio thread.
public final class AudioFeatureExtractor {
    
    // MARK: - Configuration (from AUDIO-MAPPING.md)
    
    /// Silence threshold (normalized RMS)
    /// Below this, audio is considered "silent"
    public static let silenceThreshold: Float = 0.02
    
    /// Onset detection threshold (energy delta)
    public static let onsetThreshold: Float = 0.08
    
    /// Minimum time between onset detections (100ms cooldown)
    public static let onsetCooldown: TimeInterval = 0.1
    
    /// Smoothing alpha values (exponential moving average)
    private struct SmoothingAlpha {
        static let rms: Float = 0.15
        static let centroid: Float = 0.1
        static let zcr: Float = 0.2
    }
    
    // MARK: - State
    
    private var smoothedRMS: Float = 0
    private var smoothedCentroid: Float = 0.5
    private var smoothedZCR: Float = 0
    private var previousRMS: Float = 0
    private var lastOnsetTime: TimeInterval = 0
    
    // FFT setup for spectral analysis
    private var fftSetup: vDSP_DFT_Setup?
    private let fftLength: Int = 2048
    
    // Lock for thread safety
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    public init() {
        // Create FFT setup (real-to-complex, forward transform)
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftLength),
            .FORWARD
        )
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
    
    // MARK: - Public Methods
    
    /// Extracts audio features from a PCM buffer.
    /// - Parameters:
    ///   - samples: Array of Float samples (normalized -1.0 to 1.0)
    ///   - sampleRate: Sample rate in Hz (e.g., 48000)
    ///   - currentTime: Current time for onset detection cooldown
    /// - Returns: Extracted and smoothed audio features
    public func extractFeatures(
        from samples: [Float],
        sampleRate: Float,
        currentTime: TimeInterval
    ) -> AudioFeatures {
        lock.lock()
        defer { lock.unlock() }
        
        guard samples.count >= 256 else {
            return AudioFeatures.silent
        }
        
        // 1. Calculate RMS Energy
        let rawRMS = calculateRMS(samples)
        smoothedRMS = applySmoothing(
            current: rawRMS,
            previous: smoothedRMS,
            alpha: SmoothingAlpha.rms
        )
        
        // 2. Calculate Spectral Centroid (requires FFT)
        let rawCentroid = calculateSpectralCentroid(samples, sampleRate: sampleRate)
        smoothedCentroid = applySmoothing(
            current: rawCentroid,
            previous: smoothedCentroid,
            alpha: SmoothingAlpha.centroid
        )
        
        // 3. Calculate Zero-Crossing Rate
        let rawZCR = calculateZeroCrossingRate(samples)
        smoothedZCR = applySmoothing(
            current: rawZCR,
            previous: smoothedZCR,
            alpha: SmoothingAlpha.zcr
        )
        
        // 4. Onset Detection
        let (onsetDetected, onsetMagnitude) = detectOnset(
            currentRMS: rawRMS,
            currentTime: currentTime
        )
        
        // 5. Silence Detection
        let isSilent = smoothedRMS < Self.silenceThreshold
        
        // Update previous RMS for next onset detection
        previousRMS = rawRMS
        
        return AudioFeatures(
            rms: smoothedRMS,
            spectralCentroid: smoothedCentroid,
            zeroCrossingRate: smoothedZCR,
            onsetDetected: onsetDetected,
            onsetMagnitude: onsetMagnitude,
            isSilent: isSilent
        )
    }
    
    /// Resets all smoothed values to initial state.
    /// Call when starting a new recording or playback session.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        smoothedRMS = 0
        smoothedCentroid = 0.5
        smoothedZCR = 0
        previousRMS = 0
        lastOnsetTime = 0
    }
    
    // MARK: - Feature Calculations
    
    /// Calculates Root Mean Square (RMS) energy.
    /// RMS = sqrt(sum(sample²) / bufferSize)
    private func calculateRMS(_ samples: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return min(rms, 1.0) // Clamp to normalized range
    }
    
    /// Calculates Spectral Centroid using FFT.
    /// Centroid = sum(frequency * magnitude) / sum(magnitude)
    /// Returns normalized value (0.0 - 1.0)
    private func calculateSpectralCentroid(_ samples: [Float], sampleRate: Float) -> Float {
        guard let setup = fftSetup, samples.count >= fftLength else {
            return 0.5 // Default to middle
        }
        
        // Prepare input (take first fftLength samples)
        var input = Array(samples.prefix(fftLength))
        
        // Apply Hann window to reduce spectral leakage
        var window = [Float](repeating: 0, count: fftLength)
        vDSP_hann_window(&window, vDSP_Length(fftLength), Int32(vDSP_HANN_NORM))
        vDSP_vmul(input, 1, window, 1, &input, 1, vDSP_Length(fftLength))
        
        // Split into real and imaginary parts for DFT
        var realInput = [Float](repeating: 0, count: fftLength)
        var imagInput = [Float](repeating: 0, count: fftLength)
        var realOutput = [Float](repeating: 0, count: fftLength)
        var imagOutput = [Float](repeating: 0, count: fftLength)
        
        // Copy windowed samples to real part
        realInput = input
        
        // Execute DFT
        vDSP_DFT_Execute(setup, realInput, imagInput, &realOutput, &imagOutput)
        
        // Calculate magnitude spectrum
        let halfLength = fftLength / 2
        var magnitudes = [Float](repeating: 0, count: halfLength)
        
        for i in 0..<halfLength {
            magnitudes[i] = sqrt(realOutput[i] * realOutput[i] + imagOutput[i] * imagOutput[i])
        }
        
        // Calculate spectral centroid
        let frequencyBinWidth = sampleRate / Float(fftLength)
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        
        for i in 0..<halfLength {
            let frequency = Float(i) * frequencyBinWidth
            weightedSum += frequency * magnitudes[i]
            magnitudeSum += magnitudes[i]
        }
        
        guard magnitudeSum > 0 else { return 0.5 }
        
        let centroid = weightedSum / magnitudeSum
        let nyquist = sampleRate / 2.0
        
        // Normalize to 0.0 - 1.0 range
        return min(max(centroid / nyquist, 0.0), 1.0)
    }
    
    /// Calculates Zero-Crossing Rate.
    /// ZCR = count(sign(sample[i]) ≠ sign(sample[i-1])) / bufferSize
    private func calculateZeroCrossingRate(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0 }
        
        var crossings = 0
        
        for i in 1..<samples.count {
            let currentSign = samples[i] >= 0
            let previousSign = samples[i - 1] >= 0
            if currentSign != previousSign {
                crossings += 1
            }
        }
        
        return Float(crossings) / Float(samples.count - 1)
    }
    
    /// Detects onset (sudden energy increase).
    /// Returns (detected, magnitude) tuple.
    private func detectOnset(currentRMS: Float, currentTime: TimeInterval) -> (Bool, Float) {
        let energyDelta = currentRMS - previousRMS
        
        // Check if energy delta exceeds threshold
        guard energyDelta > Self.onsetThreshold else {
            return (false, 0)
        }
        
        // Check cooldown period (100ms minimum between onsets)
        guard currentTime - lastOnsetTime > Self.onsetCooldown else {
            return (false, 0)
        }
        
        // Onset detected!
        lastOnsetTime = currentTime
        
        // Calculate onset magnitude (normalized)
        let magnitude = min(energyDelta / Self.onsetThreshold, 1.0)
        
        return (true, magnitude)
    }
    
    /// Applies exponential moving average smoothing.
    /// smoothed = α * current + (1 - α) * previous
    private func applySmoothing(current: Float, previous: Float, alpha: Float) -> Float {
        return alpha * current + (1.0 - alpha) * previous
    }
}

// MARK: - AudioFeatures Extension for Force Mapping

extension AudioFeatures {
    
    // Force scaling constants from AUDIO-MAPPING.md
    private static let expansionScale: Float = 0.03  // 3% max
    private static let tensionBase: Float = 10.0
    private static let tensionRange: Float = 5.0
    private static let rippleAmplitude: Float = 0.005  // 0.5% local
    private static let impulseScale: Float = 0.5
    
    /// Calculates radial force from RMS energy.
    /// Per AUDIO-MAPPING.md: force = smoothedRMS * expansionScale * baseRadius
    public func radialForce(baseRadius: Float = 1.0) -> Float {
        return rms * Self.expansionScale * baseRadius
    }
    
    /// Calculates surface tension from spectral centroid.
    /// Per AUDIO-MAPPING.md: tension = baseTension + (centroid * tensionRange)
    public func surfaceTension() -> Float {
        return Self.tensionBase + (spectralCentroid * Self.tensionRange)
    }
    
    /// Calculates ripple amplitude from zero-crossing rate.
    /// Per AUDIO-MAPPING.md: amplitude = smoothedZCR * rippleAmplitude
    public func rippleForce(baseRadius: Float = 1.0) -> Float {
        return zeroCrossingRate * Self.rippleAmplitude * baseRadius
    }
    
    /// Calculates impulse force from onset detection.
    /// Per AUDIO-MAPPING.md: force = onsetMagnitude * impulseScale
    public func impulseForce() -> Float {
        guard onsetDetected else { return 0 }
        return onsetMagnitude * Self.impulseScale
    }
}
