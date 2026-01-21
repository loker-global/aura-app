import Foundation
import AVFoundation

/// Protocol for receiving playback events
protocol AudioPlayerDelegate: AnyObject {
    func audioPlayer(_ player: AudioPlayer, didReceiveAnalysis analysis: AudioAnalysis)
    func audioPlayerDidFinishPlaying(_ player: AudioPlayer)
}

/// Wraps AVAudioPlayerNode for audio playback
/// Provides real-time metering during playback
/// Delivers audio analysis to orb during replay
final class AudioPlayer {
    
    // MARK: - Properties
    
    weak var delegate: AudioPlayerDelegate?
    
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let analyzer: AudioAnalyzer
    
    private var audioFile: AVAudioFile?
    private var isPlaying = false
    
    // Playback state
    private(set) var duration: TimeInterval = 0
    private(set) var currentTime: TimeInterval = 0
    
    // MARK: - Initialization
    
    init() {
        analyzer = AudioAnalyzer(bufferSize: 2048, sampleRate: 48000.0)
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)
    }
    
    // MARK: - Public Methods
    
    /// Load audio file for playback
    func loadFile(url: URL) throws {
        audioFile = try AVAudioFile(forReading: url)
        
        if let file = audioFile {
            duration = Double(file.length) / file.processingFormat.sampleRate
        }
    }
    
    /// Start playback
    func play() throws {
        guard let file = audioFile, !isPlaying else { return }
        
        // Install tap for analysis
        let format = file.processingFormat
        audioEngine.mainMixerNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, time in
            self?.processPlaybackBuffer(buffer)
        }
        
        // Schedule file
        playerNode.scheduleFile(file, at: nil) { [weak self] in
            DispatchQueue.main.async {
                self?.handlePlaybackFinished()
            }
        }
        
        // Start engine and player
        try audioEngine.start()
        playerNode.play()
        isPlaying = true
    }
    
    /// Pause playback
    func pause() {
        guard isPlaying else { return }
        playerNode.pause()
    }
    
    /// Resume playback
    func resume() {
        guard !isPlaying else { return }
        playerNode.play()
    }
    
    /// Stop playback
    func stop() {
        playerNode.stop()
        audioEngine.mainMixerNode.removeTap(onBus: 0)
        audioEngine.stop()
        isPlaying = false
        currentTime = 0
    }
    
    /// Seek to position (0.0 to 1.0)
    func seek(to position: Double) {
        guard let file = audioFile else { return }
        
        let wasPlaying = isPlaying
        playerNode.stop()
        
        let framePosition = AVAudioFramePosition(position * Double(file.length))
        let framesRemaining = AVAudioFrameCount(file.length - framePosition)
        
        playerNode.scheduleSegment(file, startingFrame: framePosition, frameCount: framesRemaining, at: nil) { [weak self] in
            DispatchQueue.main.async {
                self?.handlePlaybackFinished()
            }
        }
        
        currentTime = position * duration
        
        if wasPlaying {
            playerNode.play()
        }
    }
    
    /// Check if currently playing
    var isActive: Bool {
        return isPlaying
    }
    
    // MARK: - Private Methods
    
    private func processPlaybackBuffer(_ buffer: AVAudioPCMBuffer) {
        let analysis = analyzer.analyze(buffer: buffer)
        
        // Update current time
        if let nodeTime = playerNode.lastRenderTime,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            currentTime = Double(playerTime.sampleTime) / playerTime.sampleRate
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.audioPlayer(self, didReceiveAnalysis: analysis)
        }
    }
    
    private func handlePlaybackFinished() {
        isPlaying = false
        audioEngine.mainMixerNode.removeTap(onBus: 0)
        audioEngine.stop()
        delegate?.audioPlayerDidFinishPlaying(self)
    }
}
