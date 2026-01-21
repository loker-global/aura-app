import Foundation
import AVFoundation
import Accelerate

/// Protocol for receiving audio analysis data
protocol AudioCaptureDelegate: AnyObject {
    func audioCaptureEngine(_ engine: AudioCaptureEngine, didReceiveAnalysis analysis: AudioAnalysis)
    func audioCaptureEngine(_ engine: AudioCaptureEngine, didReceiveBuffer buffer: AVAudioPCMBuffer)
}

/// Audio analysis data structure
struct AudioAnalysis {
    let rms: Float              // 0.0 to 1.0, overall loudness
    let spectralCentroid: Float // 0.0 to 1.0, normalized brightness
    let zeroCrossingRate: Float // 0.0 to 1.0, noisiness
    let onsetDetected: Bool     // Syllable attack
    let onsetMagnitude: Float   // 0.0 to 1.0
}

/// Wraps AVAudioEngine for audio input capture
/// Provides real-time metering and buffer delivery
/// Runs on dedicated audio thread
final class AudioCaptureEngine {
    
    // MARK: - Properties
    
    weak var delegate: AudioCaptureDelegate?
    
    private let audioEngine = AVAudioEngine()
    private let analyzer: AudioAnalyzer
    private var isCapturing = false
    
    // Buffer configuration
    private let bufferSize: AVAudioFrameCount = 2048
    private let targetSampleRate: Double = 48000.0
    
    // Track device
    private(set) var currentDevice: AudioDevice?
    
    // MARK: - Initialization
    
    init() {
        analyzer = AudioAnalyzer(bufferSize: Int(bufferSize), sampleRate: targetSampleRate)
    }
    
    // MARK: - Public Methods
    
    /// Start capturing audio from specified device
    func startCapture(device: AudioDevice? = nil) throws {
        guard !isCapturing else { return }
        
        let targetDevice = device ?? AudioDeviceRegistry.shared.defaultInputDevice()
        currentDevice = targetDevice
        
        // Configure input node
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // Install tap for audio buffers
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
        
        // Start engine
        audioEngine.prepare()
        try audioEngine.start()
        
        isCapturing = true
    }
    
    /// Stop capturing audio
    func stopCapture() {
        guard isCapturing else { return }
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        isCapturing = false
    }
    
    /// Check if currently capturing
    var isActive: Bool {
        return isCapturing
    }
    
    // MARK: - Private Methods
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Deliver buffer to delegate
        delegate?.audioCaptureEngine(self, didReceiveBuffer: buffer)
        
        // Analyze audio
        let analysis = analyzer.analyze(buffer: buffer)
        
        // Deliver analysis to delegate (main thread for UI updates)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.audioCaptureEngine(self, didReceiveAnalysis: analysis)
        }
    }
}
