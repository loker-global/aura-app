// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// AudioPlayer.swift — Audio file playback with real-time analysis

import AVFoundation

// MARK: - AudioPlayerDelegate

/// Delegate for receiving playback events.
public protocol AudioPlayerDelegate: AnyObject {
    /// Called when playback starts.
    func audioPlayerDidStartPlaying(_ player: AudioPlayer)
    
    /// Called when playback pauses.
    func audioPlayerDidPause(_ player: AudioPlayer)
    
    /// Called when playback stops (reaches end or manually stopped).
    func audioPlayerDidStop(_ player: AudioPlayer)
    
    /// Called with audio features during playback for orb animation.
    func audioPlayer(_ player: AudioPlayer, didAnalyzeFeatures features: AudioFeatures, atTime time: TimeInterval)
    
    /// Called when playback position changes.
    func audioPlayer(_ player: AudioPlayer, didUpdatePosition position: TimeInterval, duration: TimeInterval)
    
    /// Called when an error occurs.
    func audioPlayer(_ player: AudioPlayer, didEncounterError error: AudioPlayerError)
}

// MARK: - AudioPlayerError

/// Errors that can occur during audio playback.
public enum AudioPlayerError: Error, LocalizedError {
    case fileNotFound(URL)
    case unsupportedFormat(String)
    case playbackFailed
    case seekFailed
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Could not open file. It may have been moved or deleted."
        case .unsupportedFormat(let format):
            return "This file format is not supported. Use WAV or MP3."
        case .playbackFailed:
            return "Playback failed. Try again or choose another file."
        case .seekFailed:
            return "Could not seek to position."
        }
    }
}

// MARK: - AudioPlayer

/// Wraps AVAudioPlayerNode for audio file playback with real-time feature extraction.
/// Per ARCHITECTURE.md: Provides real-time metering during playback for orb animation.
///
/// Playback equals re-embodiment — the orb replays using the same motion model.
public final class AudioPlayer {
    
    // MARK: - Types
    
    /// Playback state
    public enum State: Equatable {
        case stopped
        case playing
        case paused
    }
    
    // MARK: - Properties
    
    /// Current playback state
    public private(set) var state: State = .stopped {
        didSet {
            if state != oldValue {
                notifyStateChange()
            }
        }
    }
    
    /// Currently loaded file URL
    public private(set) var currentFileURL: URL?
    
    /// Audio file duration in seconds
    public private(set) var duration: TimeInterval = 0
    
    /// Current playback position in seconds
    public var currentPosition: TimeInterval {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return pausedPosition
        }
        return pausedPosition + (Double(playerTime.sampleTime) / playerTime.sampleRate)
    }
    
    /// Delegate for playback events
    public weak var delegate: AudioPlayerDelegate?
    
    // MARK: - Private Properties
    
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var featureExtractor = AudioFeatureExtractor()
    
    private var pausedPosition: TimeInterval = 0
    private var analysisTimer: Timer?
    
    // Buffer size for analysis (matching AudioCaptureEngine)
    private static let analysisBufferSize: AVAudioFrameCount = 2048
    private static let analysisInterval: TimeInterval = 1.0 / 60.0 // 60 Hz updates
    
    // MARK: - Initialization
    
    public init() {
        setupAudioEngine()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Setup
    
    private func setupAudioEngine() {
        // Attach player node to engine
        audioEngine.attach(playerNode)
        
        // Connect player to main mixer
        let mainMixer = audioEngine.mainMixerNode
        audioEngine.connect(playerNode, to: mainMixer, format: nil)
    }
    
    // MARK: - Public Methods
    
    /// Loads an audio file for playback.
    /// - Parameter url: URL to audio file (WAV or MP3)
    /// - Throws: AudioPlayerError if file cannot be loaded
    public func loadFile(at url: URL) throws {
        // Stop any current playback
        stop()
        
        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioPlayerError.fileNotFound(url)
        }
        
        // Open audio file
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            throw AudioPlayerError.unsupportedFormat(url.pathExtension)
        }
        
        guard let file = audioFile else {
            throw AudioPlayerError.unsupportedFormat(url.pathExtension)
        }
        
        // Calculate duration
        duration = Double(file.length) / file.fileFormat.sampleRate
        currentFileURL = url
        pausedPosition = 0
        
        // Reset feature extractor for new file
        featureExtractor.reset()
    }
    
    /// Starts playback from current position.
    public func play() {
        guard let file = audioFile else { return }
        guard state != .playing else { return }
        
        do {
            // Calculate frame position
            let framePosition = AVAudioFramePosition(pausedPosition * file.fileFormat.sampleRate)
            let framesToPlay = AVAudioFrameCount(file.length - framePosition)
            
            guard framesToPlay > 0 else {
                // Reached end of file
                stop()
                return
            }
            
            // Seek to position
            file.framePosition = framePosition
            
            // Schedule file for playback
            playerNode.scheduleSegment(
                file,
                startingFrame: framePosition,
                frameCount: framesToPlay,
                at: nil
            ) { [weak self] in
                // Playback completed
                DispatchQueue.main.async {
                    self?.handlePlaybackComplete()
                }
            }
            
            // Start engine if needed
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            
            // Start playback
            playerNode.play()
            state = .playing
            
            // Start analysis timer for feature extraction
            startAnalysisTimer()
            
            delegate?.audioPlayerDidStartPlaying(self)
            
        } catch {
            delegate?.audioPlayer(self, didEncounterError: .playbackFailed)
        }
    }
    
    /// Pauses playback.
    public func pause() {
        guard state == .playing else { return }
        
        // Save current position
        pausedPosition = currentPosition
        
        playerNode.pause()
        state = .paused
        
        stopAnalysisTimer()
        
        delegate?.audioPlayerDidPause(self)
    }
    
    /// Stops playback and resets to beginning.
    public func stop() {
        playerNode.stop()
        audioEngine.stop()
        
        pausedPosition = 0
        state = .stopped
        
        stopAnalysisTimer()
        
        delegate?.audioPlayerDidStop(self)
    }
    
    /// Seeks to a position in the file.
    /// - Parameter position: Target position in seconds
    public func seek(to position: TimeInterval) {
        guard audioFile != nil else { return }
        
        let wasPlaying = state == .playing
        
        // Stop current playback
        playerNode.stop()
        
        // Update position
        pausedPosition = max(0, min(position, duration))
        
        // Resume if was playing
        if wasPlaying {
            state = .paused // Temporarily set to paused
            play()
        }
    }
    
    /// Toggles between play and pause.
    public func togglePlayPause() {
        switch state {
        case .playing:
            pause()
        case .paused, .stopped:
            play()
        }
    }
    
    // MARK: - Feature Extraction for Playback
    
    private func startAnalysisTimer() {
        stopAnalysisTimer()
        
        // Create timer for 60 Hz analysis updates
        analysisTimer = Timer.scheduledTimer(
            withTimeInterval: Self.analysisInterval,
            repeats: true
        ) { [weak self] _ in
            self?.analyzeCurrentPosition()
        }
        
        // Add to common run loop mode for responsiveness
        if let timer = analysisTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopAnalysisTimer() {
        analysisTimer?.invalidate()
        analysisTimer = nil
    }
    
    private func analyzeCurrentPosition() {
        guard state == .playing, let file = audioFile else { return }
        
        let position = currentPosition
        
        // Extract features at current position
        let features = extractFeaturesAt(position: position, from: file)
        
        // Notify delegate
        delegate?.audioPlayer(self, didAnalyzeFeatures: features, atTime: position)
        delegate?.audioPlayer(self, didUpdatePosition: position, duration: duration)
    }
    
    private func extractFeaturesAt(position: TimeInterval, from file: AVAudioFile) -> AudioFeatures {
        let sampleRate = file.fileFormat.sampleRate
        let framePosition = AVAudioFramePosition(position * sampleRate)
        
        // Read buffer at position
        let bufferSize = Self.analysisBufferSize
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: bufferSize) else {
            return .silent
        }
        
        // Temporarily seek to position (restore after)
        let originalPosition = file.framePosition
        file.framePosition = max(0, framePosition - AVAudioFramePosition(bufferSize / 2))
        
        do {
            try file.read(into: buffer)
            file.framePosition = originalPosition
            
            // Extract samples
            guard let channelData = buffer.floatChannelData else {
                return .silent
            }
            
            let frameCount = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
            
            // Extract features
            return featureExtractor.extractFeatures(
                from: samples,
                sampleRate: Float(sampleRate),
                currentTime: position
            )
            
        } catch {
            file.framePosition = originalPosition
            return .silent
        }
    }
    
    private func handlePlaybackComplete() {
        state = .stopped
        pausedPosition = 0
        stopAnalysisTimer()
        delegate?.audioPlayerDidStop(self)
    }
    
    private func notifyStateChange() {
        // Notify delegate of state change
        switch state {
        case .playing:
            delegate?.audioPlayerDidStartPlaying(self)
        case .paused:
            delegate?.audioPlayerDidPause(self)
        case .stopped:
            delegate?.audioPlayerDidStop(self)
        }
    }
}

// MARK: - Supported Formats

extension AudioPlayer {
    
    /// Supported audio file extensions
    public static let supportedExtensions: Set<String> = ["wav", "mp3", "m4a", "aac", "aif", "aiff"]
    
    /// Checks if a file is a supported audio format.
    /// - Parameter url: File URL to check
    /// - Returns: True if the file extension is supported
    public static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
