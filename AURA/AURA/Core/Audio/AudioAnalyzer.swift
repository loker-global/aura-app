import Foundation
import AVFoundation
import Accelerate

/// Audio feature analyzer
/// Extracts RMS, spectral centroid, ZCR, and onset detection
final class AudioAnalyzer {
    
    // MARK: - Configuration (from AUDIO-MAPPING.md)
    
    private let bufferSize: Int
    private let sampleRate: Double
    
    // Smoothing alphas
    private let rmsAlpha: Float = 0.15
    private let centroidAlpha: Float = 0.1
    private let zcrAlpha: Float = 0.2
    
    // Onset detection
    private let onsetThreshold: Float = 0.08
    private let onsetCooldown: TimeInterval = 0.1
    
    // Silence threshold
    private let silenceThreshold: Float = 0.02
    
    // MARK: - State
    
    private var smoothedRMS: Float = 0
    private var smoothedCentroid: Float = 0
    private var smoothedZCR: Float = 0
    private var previousRMS: Float = 0
    private var lastOnsetTime: Date?
    
    // FFT setup
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]
    
    // MARK: - Initialization
    
    init(bufferSize: Int, sampleRate: Double) {
        self.bufferSize = bufferSize
        self.sampleRate = sampleRate
        
        // Create FFT setup
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(bufferSize),
            .FORWARD
        )
        
        // Create Hann window
        window = [Float](repeating: 0, count: bufferSize)
        vDSP_hann_window(&window, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }
    
    // MARK: - Analysis
    
    func analyze(buffer: AVAudioPCMBuffer) -> AudioAnalysis {
        guard let floatData = buffer.floatChannelData?[0] else {
            return AudioAnalysis(
                rms: 0,
                spectralCentroid: 0,
                zeroCrossingRate: 0,
                onsetDetected: false,
                onsetMagnitude: 0
            )
        }
        
        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: floatData, count: frameCount))
        
        // Calculate features
        let currentRMS = calculateRMS(samples: samples)
        let currentCentroid = calculateSpectralCentroid(samples: samples)
        let currentZCR = calculateZeroCrossingRate(samples: samples)
        let (onsetDetected, onsetMagnitude) = detectOnset(currentRMS: currentRMS)
        
        // Apply smoothing
        smoothedRMS = rmsAlpha * currentRMS + (1 - rmsAlpha) * smoothedRMS
        smoothedCentroid = centroidAlpha * currentCentroid + (1 - centroidAlpha) * smoothedCentroid
        smoothedZCR = zcrAlpha * currentZCR + (1 - zcrAlpha) * smoothedZCR
        
        // Update previous RMS for next onset detection
        previousRMS = currentRMS
        
        return AudioAnalysis(
            rms: smoothedRMS,
            spectralCentroid: smoothedCentroid,
            zeroCrossingRate: smoothedZCR,
            onsetDetected: onsetDetected,
            onsetMagnitude: onsetMagnitude
        )
    }
    
    // MARK: - Feature Calculations
    
    /// RMS = sqrt(sum(sample²) / bufferSize)
    private func calculateRMS(samples: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return min(rms, 1.0)
    }
    
    /// Spectral Centroid = sum(frequency * magnitude) / sum(magnitude)
    private func calculateSpectralCentroid(samples: [Float]) -> Float {
        guard let setup = fftSetup else { return 0 }
        
        // Apply window
        var windowedSamples = [Float](repeating: 0, count: bufferSize)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, vDSP_Length(bufferSize))
        
        // Prepare for FFT
        var realInput = windowedSamples
        var imagInput = [Float](repeating: 0, count: bufferSize)
        var realOutput = [Float](repeating: 0, count: bufferSize)
        var imagOutput = [Float](repeating: 0, count: bufferSize)
        
        // Perform FFT
        vDSP_DFT_Execute(setup, &realInput, &imagInput, &realOutput, &imagOutput)
        
        // Calculate magnitude spectrum
        let halfN = bufferSize / 2
        var magnitudes = [Float](repeating: 0, count: halfN)
        
        for i in 0..<halfN {
            let real = realOutput[i]
            let imag = imagOutput[i]
            magnitudes[i] = sqrt(real * real + imag * imag)
        }
        
        // Calculate spectral centroid
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        
        let frequencyResolution = Float(sampleRate) / Float(bufferSize)
        
        for i in 0..<halfN {
            let frequency = Float(i) * frequencyResolution
            weightedSum += frequency * magnitudes[i]
            magnitudeSum += magnitudes[i]
        }
        
        guard magnitudeSum > 0 else { return 0 }
        
        let centroid = weightedSum / magnitudeSum
        let nyquist = Float(sampleRate / 2.0)
        
        // Normalize to 0.0 - 1.0
        return min(centroid / nyquist, 1.0)
    }
    
    /// ZCR = count(sign changes) / bufferSize
    private func calculateZeroCrossingRate(samples: [Float]) -> Float {
        var crossings: Int = 0
        
        for i in 1..<samples.count {
            if (samples[i] >= 0 && samples[i-1] < 0) || (samples[i] < 0 && samples[i-1] >= 0) {
                crossings += 1
            }
        }
        
        return Float(crossings) / Float(samples.count)
    }
    
    /// Onset detection: sudden energy increases
    private func detectOnset(currentRMS: Float) -> (detected: Bool, magnitude: Float) {
        let energyDelta = currentRMS - previousRMS
        
        // Check cooldown
        if let lastOnset = lastOnsetTime {
            let elapsed = Date().timeIntervalSince(lastOnset)
            if elapsed < onsetCooldown {
                return (false, 0)
            }
        }
        
        // Detect onset
        if energyDelta > onsetThreshold {
            lastOnsetTime = Date()
            let magnitude = min(energyDelta / 0.5, 1.0)
            return (true, magnitude)
        }
        
        return (false, 0)
    }
    
    /// Reset analyzer state
    func reset() {
        smoothedRMS = 0
        smoothedCentroid = 0
        smoothedZCR = 0
        previousRMS = 0
        lastOnsetTime = nil
    }
}
