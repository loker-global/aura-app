import XCTest
import AVFoundation
@testable import AURA

final class AudioTests: XCTestCase {
    
    func testAudioDeviceRegistry() {
        let registry = AudioDeviceRegistry.shared
        
        // Should return devices (may be empty in CI)
        let devices = registry.availableInputDevices()
        // Just verify it doesn't crash
        XCTAssertNotNil(devices)
    }
    
    func testAudioAnalyzerInitialization() {
        let analyzer = AudioAnalyzer(bufferSize: 2048, sampleRate: 48000.0)
        XCTAssertNotNil(analyzer)
    }
    
    func testAudioAnalyzerSilence() {
        let analyzer = AudioAnalyzer(bufferSize: 2048, sampleRate: 48000.0)
        
        // Create silent buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000.0, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2048) else {
            XCTFail("Could not create buffer")
            return
        }
        buffer.frameLength = 2048
        
        // Fill with silence
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<Int(buffer.frameLength) {
                channelData[i] = 0.0
            }
        }
        
        let analysis = analyzer.analyze(buffer: buffer)
        
        // Silence should have near-zero RMS
        XCTAssertLessThan(analysis.rms, 0.01)
        XCTAssertFalse(analysis.onsetDetected)
    }
    
    func testAudioAnalyzerImpulse() {
        let analyzer = AudioAnalyzer(bufferSize: 2048, sampleRate: 48000.0)
        
        // Create buffer with impulse
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000.0, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2048) else {
            XCTFail("Could not create buffer")
            return
        }
        buffer.frameLength = 2048
        
        // Fill with impulse (loud signal)
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<Int(buffer.frameLength) {
                channelData[i] = sin(Float(i) * 0.1) * 0.8
            }
        }
        
        let analysis = analyzer.analyze(buffer: buffer)
        
        // Impulse should have higher RMS
        XCTAssertGreaterThan(analysis.rms, 0.1)
    }
    
    func testWavRecorderDefaultURL() {
        let url = WavRecorder.defaultRecordingURL()
        
        // Should be in Documents/AURA Recordings
        XCTAssertTrue(url.path.contains("AURA Recordings"))
        XCTAssertTrue(url.pathExtension == "wav")
    }
}
