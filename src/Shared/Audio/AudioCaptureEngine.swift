// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// AudioCaptureEngine.swift — AVAudioEngine wrapper with real-time metering

import AVFoundation

// MARK: - AudioCaptureDelegate

/// Delegate protocol for receiving audio capture events.
public protocol AudioCaptureDelegate: AnyObject {
    /// Called when audio buffer is captured with extracted features.
    /// Called on audio thread - minimize work!
    func audioCaptureEngine(_ engine: AudioCaptureEngine, didCaptureBuffer buffer: AVAudioPCMBuffer, features: AudioFeatures)
    
    /// Called when an error occurs during capture.
    func audioCaptureEngine(_ engine: AudioCaptureEngine, didEncounterError error: AudioCaptureError)
    
    /// Called when capture state changes.
    func audioCaptureEngine(_ engine: AudioCaptureEngine, didChangeState state: AudioCaptureEngine.State)
}

// MARK: - AudioCaptureError

/// Errors that can occur during audio capture.
public enum AudioCaptureError: Error, LocalizedError {
    case permissionDenied
    case deviceUnavailable(String)
    case deviceInUse(String)
    case engineStartFailed
    case bufferAllocationFailed
    case unexpectedFormat
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access is required to record."
        case .deviceUnavailable(let name):
            return "Could not access \(name). It may be unavailable."
        case .deviceInUse(let name):
            return "Could not access \(name). It may be in use by another app."
        case .engineStartFailed:
            return "Audio engine failed to start. Try restarting the app."
        case .bufferAllocationFailed:
            return "Failed to allocate audio buffer."
        case .unexpectedFormat:
            return "Unexpected audio format from device."
        }
    }
}

// MARK: - AudioCaptureEngine

/// Wraps AVAudioEngine for real-time audio capture and metering.
/// Per ARCHITECTURE.md: Runs on dedicated audio thread, never blocks UI.
///
/// Priority: Audio > Rendering > UI
/// - Audio thread: real-time priority, never blocked
/// - Delivers audio buffers to recorder + orb physics
public final class AudioCaptureEngine {
    
    // MARK: - Types
    
    /// Capture engine state
    public enum State: Equatable {
        case stopped
        case starting
        case running
        case error(String)
    }
    
    // MARK: - Configuration (from AUDIO-MAPPING.md)
    
    /// Preferred sample rate (48kHz for voice)
    public static let preferredSampleRate: Double = 48000.0
    
    /// Buffer size in samples (~43ms at 48kHz)
    public static let bufferSize: AVAudioFrameCount = 2048
    
    // MARK: - Properties
    
    /// Current capture state
    public private(set) var state: State = .stopped {
        didSet {
            if state != oldValue {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.audioCaptureEngine(self, didChangeState: self.state)
                }
            }
        }
    }
    
    /// Currently selected audio device
    public private(set) var currentDevice: AudioDevice?
    
    /// Current audio format
    public private(set) var audioFormat: AVAudioFormat?
    
    /// Delegate for receiving capture events
    public weak var delegate: AudioCaptureDelegate?
    
    // MARK: - Private Properties
    
    private let audioEngine: AVAudioEngine
    private let featureExtractor: AudioFeatureExtractor
    private var inputNode: AVAudioInputNode { audioEngine.inputNode }
    
    // Time tracking for feature extraction
    private var startTime: TimeInterval = 0
    
    // Queue for thread-safe operations
    private let engineQueue = DispatchQueue(label: "com.aura.audioEngine", qos: .userInteractive)
    
    #if os(macOS)
    private var audioDeviceID: AudioDeviceID?
    #endif
    
    // MARK: - Initialization
    
    public init() {
        audioEngine = AVAudioEngine()
        featureExtractor = AudioFeatureExtractor()
        
        // Configure audio session on iOS
        #if os(iOS)
        configureAudioSession()
        #endif
        
        setupInterruptionHandling()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    
    /// Requests microphone permission.
    /// - Parameter completion: Called with true if permission granted
    public func requestPermission(completion: @escaping (Bool) -> Void) {
        #if os(iOS)
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
        #else
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
        #endif
    }
    
    /// Selects an audio input device.
    /// - Parameter device: The device to select
    /// - Throws: AudioCaptureError if device cannot be selected
    public func selectDevice(_ device: AudioDevice) throws {
        guard state == .stopped else {
            throw AudioCaptureError.deviceInUse(device.name)
        }
        
        #if os(macOS)
        // Set the audio device on macOS
        guard let deviceID = AudioDeviceID(device.id) else {
            throw AudioCaptureError.deviceUnavailable(device.name)
        }
        
        var deviceIDValue = deviceID
        let propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Note: We'll set the device when the engine starts
        audioDeviceID = deviceID
        currentDevice = device
        #else
        // On iOS, device switching is handled by AVAudioSession
        if let inputs = AVAudioSession.sharedInstance().availableInputs,
           let port = inputs.first(where: { $0.uid == device.id }) {
            do {
                try AVAudioSession.sharedInstance().setPreferredInput(port)
                currentDevice = device
            } catch {
                throw AudioCaptureError.deviceUnavailable(device.name)
            }
        }
        #endif
    }
    
    /// Starts audio capture.
    /// - Throws: AudioCaptureError if capture cannot start
    public func start() throws {
        engineQueue.sync {
            guard state == .stopped else { return }
            state = .starting
        }
        
        do {
            // Reset feature extractor for new session
            featureExtractor.reset()
            startTime = CACurrentMediaTime()
            
            #if os(macOS)
            // Configure device on macOS
            if let deviceID = audioDeviceID {
                try setInputDevice(deviceID)
            }
            #endif
            
            // Get the input format
            let inputFormat = inputNode.outputFormat(forBus: 0)
            guard inputFormat.sampleRate > 0 else {
                throw AudioCaptureError.unexpectedFormat
            }
            
            audioFormat = inputFormat
            
            // Install tap on input node
            inputNode.installTap(
                onBus: 0,
                bufferSize: Self.bufferSize,
                format: inputFormat
            ) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer, time: time)
            }
            
            // Prepare and start the engine
            audioEngine.prepare()
            try audioEngine.start()
            
            state = .running
            
        } catch {
            state = .error(error.localizedDescription)
            throw AudioCaptureError.engineStartFailed
        }
    }
    
    /// Stops audio capture.
    public func stop() {
        engineQueue.sync {
            guard state == .running || state == .starting else { return }
            
            inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            
            state = .stopped
        }
    }
    
    // MARK: - Private Methods
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Extract samples from buffer
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        
        // Calculate current time for onset detection
        let currentTime = CACurrentMediaTime() - startTime
        
        // Extract audio features
        let features = featureExtractor.extractFeatures(
            from: samples,
            sampleRate: Float(audioFormat?.sampleRate ?? Self.preferredSampleRate),
            currentTime: currentTime
        )
        
        // Notify delegate (called on audio thread!)
        delegate?.audioCaptureEngine(self, didCaptureBuffer: buffer, features: features)
    }
    
    #if os(macOS)
    private func setInputDevice(_ deviceID: AudioDeviceID) throws {
        var deviceID = deviceID
        let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioUnitSetProperty(
            inputNode.audioUnit!,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            propertySize
        )
        
        if status != noErr {
            throw AudioCaptureError.deviceUnavailable("Device \(deviceID)")
        }
    }
    #endif
    
    #if os(iOS)
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP
            ])
            try session.setPreferredSampleRate(Self.preferredSampleRate)
            try session.setPreferredIOBufferDuration(Double(Self.bufferSize) / Self.preferredSampleRate)
            try session.setActive(true)
        } catch {
            // Log error but don't throw - session will be configured when recording starts
            print("[AudioCaptureEngine] Failed to configure audio session: \(error)")
        }
    }
    #endif
    
    private func setupInterruptionHandling() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        #endif
    }
    
    #if os(iOS)
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began - stop capture
            stop()
            delegate?.audioCaptureEngine(self, didEncounterError: .deviceUnavailable("Audio interrupted"))
            
        case .ended:
            // Interruption ended - could restart if needed
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Could auto-restart here if desired
                }
            }
            
        @unknown default:
            break
        }
    }
    #endif
}

// MARK: - Extension for Getting Current Audio Level

extension AudioCaptureEngine {
    /// Returns instantaneous audio level (0.0 - 1.0) for metering.
    /// This is a convenience for UI display, not physics.
    public func getCurrentLevel() -> Float {
        guard state == .running else { return 0 }
        
        var level: Float = 0
        inputNode.installTap(onBus: 0, bufferSize: 256, format: nil) { buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            let samples = UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength))
            
            var rms: Float = 0
            vDSP_rmsqv(Array(samples), 1, &rms, vDSP_Length(buffer.frameLength))
            level = rms
        }
        inputNode.removeTap(onBus: 0)
        
        return min(level, 1.0)
    }
}
