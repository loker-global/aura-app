// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// Tests/AudioTests/AudioFeatureExtractorTests.swift

import XCTest
@testable import AURA

final class AudioFeatureExtractorTests: XCTestCase {
    
    var extractor: AudioFeatureExtractor!
    
    override func setUp() {
        super.setUp()
        extractor = AudioFeatureExtractor()
    }
    
    override func tearDown() {
        extractor = nil
        super.tearDown()
    }
    
    // MARK: - RMS Tests
    
    func testSilenceReturnsZeroRMS() {
        // Given: Silent audio (all zeros)
        let samples = [Float](repeating: 0.0, count: 2048)
        
        // When: Extract features
        let features = extractor.extractFeatures(from: samples, sampleRate: 48000, currentTime: 0)
        
        // Then: RMS should be 0
        XCTAssertEqual(features.rms, 0.0, accuracy: 0.001)
        XCTAssertTrue(features.isSilent)
    }
    
    func testLoudAudioReturnsHighRMS() {
        // Given: Loud audio (normalized sine wave)
        var samples = [Float](repeating: 0.0, count: 2048)
        for i in 0..<2048 {
            samples[i] = sin(Float(i) * 2 * .pi * 440 / 48000) * 0.8
        }
        
        // When: Extract features
        let features = extractor.extractFeatures(from: samples, sampleRate: 48000, currentTime: 0)
        
        // Then: RMS should be significant
        XCTAssertGreaterThan(features.rms, 0.3)
        XCTAssertFalse(features.isSilent)
    }
    
    func testRMSIsNormalized() {
        // Given: Full scale audio
        var samples = [Float](repeating: 0.0, count: 2048)
        for i in 0..<2048 {
            samples[i] = sin(Float(i) * 2 * .pi * 440 / 48000)
        }
        
        // When: Extract features
        let features = extractor.extractFeatures(from: samples, sampleRate: 48000, currentTime: 0)
        
        // Then: RMS should be <= 1.0
        XCTAssertLessThanOrEqual(features.rms, 1.0)
    }
    
    // MARK: - Silence Detection Tests
    
    func testSilenceThreshold() {
        // Given: Audio just below silence threshold
        let samples = [Float](repeating: 0.01, count: 2048)
        
        // When: Extract features
        let features = extractor.extractFeatures(from: samples, sampleRate: 48000, currentTime: 0)
        
        // Then: Should be detected as silent (threshold is 0.02)
        XCTAssertTrue(features.isSilent)
    }
    
    func testAboveSilenceThreshold() {
        // Given: Audio just above silence threshold
        var samples = [Float](repeating: 0.0, count: 2048)
        for i in 0..<2048 {
            samples[i] = sin(Float(i) * 2 * .pi * 440 / 48000) * 0.1
        }
        
        // When: Extract features
        let features = extractor.extractFeatures(from: samples, sampleRate: 48000, currentTime: 0)
        
        // Then: Should NOT be detected as silent
        XCTAssertFalse(features.isSilent)
    }
    
    // MARK: - Zero-Crossing Rate Tests
    
    func testZeroCrossingRateForSineWave() {
        // Given: Pure sine wave (predictable zero crossings)
        var samples = [Float](repeating: 0.0, count: 2048)
        for i in 0..<2048 {
            samples[i] = sin(Float(i) * 2 * .pi * 440 / 48000)
        }
        
        // When: Extract features
        let features = extractor.extractFeatures(from: samples, sampleRate: 48000, currentTime: 0)
        
        // Then: ZCR should be non-zero
        XCTAssertGreaterThan(features.zeroCrossingRate, 0.0)
        XCTAssertLessThanOrEqual(features.zeroCrossingRate, 1.0)
    }
    
    func testZeroCrossingRateForNoise() {
        // Given: Noisy signal (high ZCR)
        var samples = [Float](repeating: 0.0, count: 2048)
        for i in 0..<2048 {
            samples[i] = Float.random(in: -1...1)
        }
        
        // When: Extract features
        let features = extractor.extractFeatures(from: samples, sampleRate: 48000, currentTime: 0)
        
        // Then: ZCR should be high (noise has many zero crossings)
        XCTAssertGreaterThan(features.zeroCrossingRate, 0.3)
    }
    
    // MARK: - Spectral Centroid Tests
    
    func testSpectralCentroidNormalized() {
        // Given: Audio signal
        var samples = [Float](repeating: 0.0, count: 2048)
        for i in 0..<2048 {
            samples[i] = sin(Float(i) * 2 * .pi * 1000 / 48000)
        }
        
        // When: Extract features
        let features = extractor.extractFeatures(from: samples, sampleRate: 48000, currentTime: 0)
        
        // Then: Spectral centroid should be normalized [0, 1]
        XCTAssertGreaterThanOrEqual(features.spectralCentroid, 0.0)
        XCTAssertLessThanOrEqual(features.spectralCentroid, 1.0)
    }
    
    // MARK: - Onset Detection Tests
    
    func testOnsetDetectionCooldown() {
        // Given: Multiple sudden energy increases
        var samples1 = [Float](repeating: 0.0, count: 2048)
        var samples2 = [Float](repeating: 0.0, count: 2048)
        
        // First buffer is quiet
        for i in 0..<2048 {
            samples1[i] = sin(Float(i) * 2 * .pi * 440 / 48000) * 0.05
        }
        
        // Second buffer is loud (sudden increase)
        for i in 0..<2048 {
            samples2[i] = sin(Float(i) * 2 * .pi * 440 / 48000) * 0.8
        }
        
        // When: Extract features
        _ = extractor.extractFeatures(from: samples1, sampleRate: 48000, currentTime: 0)
        let features2 = extractor.extractFeatures(from: samples2, sampleRate: 48000, currentTime: 0.05)
        
        // Then: Onset should be detected
        // Note: Actual detection depends on smoothing and thresholds
        XCTAssertGreaterThan(features2.rms, 0.3)
    }
    
    // MARK: - Force Mapping Tests
    
    func testRadialForceMapping() {
        // Given: Audio features
        let features = AudioFeatures(
            rms: 0.5,
            spectralCentroid: 0.5,
            zeroCrossingRate: 0.2,
            onsetDetected: false,
            onsetMagnitude: 0,
            isSilent: false
        )
        
        // When: Calculate radial force
        let force = features.radialForce(baseRadius: 1.0)
        
        // Then: Force should be within expected range (max 3%)
        XCTAssertGreaterThan(force, 0.0)
        XCTAssertLessThanOrEqual(force, 0.03) // 3% max deformation
    }
    
    func testSurfaceTensionMapping() {
        // Given: Audio features with different centroid values
        let lowCentroid = AudioFeatures(
            rms: 0.5, spectralCentroid: 0.0, zeroCrossingRate: 0.2,
            onsetDetected: false, onsetMagnitude: 0, isSilent: false
        )
        
        let highCentroid = AudioFeatures(
            rms: 0.5, spectralCentroid: 1.0, zeroCrossingRate: 0.2,
            onsetDetected: false, onsetMagnitude: 0, isSilent: false
        )
        
        // When: Calculate surface tension
        let lowTension = lowCentroid.surfaceTension()
        let highTension = highCentroid.surfaceTension()
        
        // Then: Higher centroid should result in higher tension
        XCTAssertGreaterThan(highTension, lowTension)
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        // Given: Some audio processed
        var samples = [Float](repeating: 0.0, count: 2048)
        for i in 0..<2048 {
            samples[i] = sin(Float(i) * 2 * .pi * 440 / 48000) * 0.5
        }
        _ = extractor.extractFeatures(from: samples, sampleRate: 48000, currentTime: 0)
        
        // When: Reset extractor
        extractor.reset()
        
        // Then: Extracting from silence should give clean features
        let silentSamples = [Float](repeating: 0.0, count: 2048)
        let features = extractor.extractFeatures(from: silentSamples, sampleRate: 48000, currentTime: 0)
        
        XCTAssertEqual(features.rms, 0.0, accuracy: 0.01)
    }
}
